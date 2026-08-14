#!/usr/bin/env python3
"""Runtime GPU verification for the development image.

Run this on a GPU node (never at build time -- the builder has no GPU):

    docker run --rm --gpus all --shm-size=8g IMAGE python /opt/dotfiles/docker/verify-gpu.py

Checks, in order:
  1. torch / CUDA / NCCL versions
  2. a CUDA device is actually visible
  3. every visible device is covered by the compiled kernel architectures
  4. a real kernel runs
  5. /dev/shm is large enough for multi-process training
  6. a real NCCL all-reduce completes across every visible GPU

Use --skip-nccl on clusters that set GPU compute mode to EXCLUSIVE_PROCESS,
where the parent's CUDA context would block the spawned ranks.
"""

from __future__ import annotations

import argparse
import shutil
import socket
import sys
import time
from datetime import timedelta

import torch

NCCL_TIMEOUT_SECONDS = 300


def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def _parse_arch(entry: str) -> tuple[int, int] | None:
    """'sm_90a' -> (9, 0); 'compute_120f' -> (12, 0). None if unparseable."""
    _, _, body = entry.partition("_")
    body = body.removesuffix("a").removesuffix("f")
    if not body.isdigit() or len(body) < 2:
        return None
    return int(body[:-1]), int(body[-1])


def _nccl_worker(rank: int, world_size: int, port: int) -> None:
    """All-reduce a known tensor and assert the result. Runs in a child process."""
    import torch.distributed as dist

    torch.cuda.set_device(rank)
    # An explicit store avoids the env:// handler, which would otherwise attach
    # to an agent store if this runs inside a torchrun/elastic job.
    store = dist.TCPStore(
        "127.0.0.1",
        port,
        world_size,
        is_master=(rank == 0),
        timeout=timedelta(seconds=120),
    )
    dist.init_process_group(
        backend="nccl",
        store=store,
        rank=rank,
        world_size=world_size,
        timeout=timedelta(seconds=180),
    )
    try:
        tensor = torch.full((1024,), float(rank + 1), device=f"cuda:{rank}")
        dist.all_reduce(tensor)
        torch.cuda.synchronize()
        expected = world_size * (world_size + 1) / 2
        actual = tensor[0].item()
        if abs(actual - expected) > 1e-3:
            raise RuntimeError(f"all_reduce returned {actual}, expected {expected}")
    finally:
        dist.destroy_process_group()


def check_architectures(count: int) -> bool:
    """Fail loudly when a GPU is newer than anything this build has kernels for.

    A cubin built for sm_X.y runs on any sm_X.z with z >= y, so an exact match is
    not required. That minor-version compatibility is why sm_86 kernels drive an
    sm_89 card (L40S, L4, RTX 4090). Compatibility never crosses a major version,
    which is what rules out Blackwell here.
    """
    arch_list = torch.cuda.get_arch_list()
    print(f"kernel archs   : {' '.join(arch_list) or '(none)'}")

    compiled = {p for p in (_parse_arch(a) for a in arch_list if a.startswith("sm_")) if p}
    ptx = {p for p in (_parse_arch(a) for a in arch_list if a.startswith("compute_")) if p}

    ok = True
    for i in range(count):
        props = torch.cuda.get_device_properties(i)
        cap = (props.major, props.minor)
        if cap in compiled:
            continue
        family = [c for c in compiled if c[0] == cap[0] and c[1] <= cap[1]]
        if family:
            best = max(family)
            print(f"  note: sm_{cap[0]}{cap[1]} runs on the sm_{best[0]}{best[1]} kernels (minor-version compatible)")
            continue
        if any(p <= cap for p in ptx):
            best = max(p for p in ptx if p <= cap)
            print(f"  note: sm_{cap[0]}{cap[1]} has no native kernels; relying on PTX JIT from compute_{best[0]}{best[1]}")
            continue
        print(f"\nFAIL: device {i} ({props.name}) is sm_{cap[0]}{cap[1]}, which this torch build does not support.")
        print("This image ships CUDA 12.6 wheels covering sm_50-sm_90. Blackwell-class")
        print("GPUs (sm_100/sm_120) need a CUDA 13.x base and matching wheels; rebuild with")
        print("  CUDA_BASE=nvidia/cuda:13.0.3-cudnn-devel-ubuntu24.04 \\")
        print("  TORCH_CUDA_INDEX=https://download.pytorch.org/whl/cu130 ./docker/build.sh")
        ok = False
    return ok


def check_shm() -> None:
    usage = shutil.disk_usage("/dev/shm")
    gib = usage.total / 1024**3
    print(f"/dev/shm       : {gib:.1f} GB")
    if gib < 1:
        print("  warning: the 64 MB Docker default breaks NCCL and DataLoader workers.")
        print("  Request more shared memory (docker run --shm-size=8g, or the platform equivalent).")


def check_nccl(count: int) -> bool:
    import torch.multiprocessing as mp

    print(f"\nnccl all-reduce: running across {count} device(s)...")
    try:
        ctx = mp.spawn(_nccl_worker, args=(count, _free_port()), nprocs=count, join=False)
        deadline = time.monotonic() + NCCL_TIMEOUT_SECONDS
        while not ctx.join(timeout=10):
            if time.monotonic() > deadline:
                for proc in ctx.processes:
                    if proc.is_alive():
                        proc.kill()
                print(f"FAIL: NCCL all-reduce timed out after {NCCL_TIMEOUT_SECONDS}s.")
                print("Usual causes: /dev/shm too small, P2P or InfiniBand misconfiguration,")
                print("or stale processes holding the GPUs. Re-run with NCCL_DEBUG=INFO.")
                return False
    except Exception as exc:  # noqa: BLE001 - report whatever the backend raised
        print(f"FAIL: NCCL all-reduce failed: {type(exc).__name__}: {exc}")
        print("If this is a multi-node image check RDMA/IB, otherwise check --shm-size.")
        return False
    print("nccl all-reduce: ok")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify GPU, CUDA and NCCL support in this image.")
    parser.add_argument("--skip-nccl", action="store_true", help="skip the NCCL collective test")
    args = parser.parse_args()

    print(f"torch          : {torch.__version__}")
    print(f"built for CUDA : {torch.version.cuda}")
    print(f"NCCL           : {'.'.join(map(str, torch.cuda.nccl.version()))}")

    if not torch.cuda.is_available():
        print("\nFAIL: no CUDA device visible.")
        print("Check that the job requested a GPU and that the NVIDIA container")
        print("runtime is active (docker run --gpus all / platform GPU request).")
        return 1

    count = torch.cuda.device_count()
    print(f"devices        : {count}")
    for i in range(count):
        props = torch.cuda.get_device_properties(i)
        print(f"  [{i}] {props.name}  sm_{props.major}{props.minor}  {props.total_memory / 1e9:.1f} GB")

    ok = check_architectures(count)
    check_shm()

    if ok:
        # Exercise an actual kernel rather than trusting metadata alone.
        a = torch.randn(2048, 2048, device="cuda")
        result = (a @ a).sum().item()
        torch.cuda.synchronize()
        print(f"matmul check   : ok ({result:.4f})")

        if not args.skip_nccl:
            ok = check_nccl(count) and ok

    print("\nPASS" if ok else "\nFAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
