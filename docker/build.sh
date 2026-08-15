#!/usr/bin/env bash
set -euo pipefail

# Build (and optionally push) the GPU development image.
#
# The image always targets linux/amd64 because that is what GPU nodes run.
# On an Apple Silicon host this uses Rosetta emulation, which slows the build
# but has no effect on the published image or its speed on the cluster.

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

namespace="${DOCKER_NAMESPACE:-leoxiao}"
image="${IMAGE_NAME:-pytorch-dev}"
platform="linux/amd64"

# Supported CUDA variants. The base image and the PyTorch wheel index MUST move
# together: the wheel index, not the version string, is what selects the CUDA
# build, so pairing them here removes the main way to produce a broken image.
# Bases are digest-pinned; refresh with:
#   docker manifest inspect nvidia/cuda:<tag>
cuda_variants="cu126 cu129 cu130 cu132"

base_for_variant() {
  case "$1" in
    cu126) echo "nvidia/cuda:12.6.3-cudnn-devel-ubuntu24.04@sha256:0f8250615943f311785f9ce6379a49520a4b53c124d22b42ba859edf93af3991" ;;
    cu129) echo "nvidia/cuda:12.9.2-cudnn-devel-ubuntu24.04@sha256:b4db213759eb86d55a7271909bdad891fab300ec5700fb4f4656463b2f51980f" ;;
    cu130) echo "nvidia/cuda:13.0.3-cudnn-devel-ubuntu24.04@sha256:a85c9f5af049f0ab679c1669ae6fa8393022886739af7361e85bb96878e8cdd4" ;;
    cu132) echo "nvidia/cuda:13.2.1-cudnn-devel-ubuntu24.04@sha256:d69a8fb0e448d9d11d8561bf19e4e8b14628d7f46c04ab7762ea3d98ec139fa3" ;;
    *) return 1 ;;
  esac
}

cuda="${CUDA_VARIANT:-cu126}"
torch_version="${TORCH_VERSION:-2.13.0}"
torchvision_version="${TORCHVISION_VERSION:-0.28.0}"
# All CUDA variants share one revision axis, so a single number identifies the
# same repo state across cu126/cu130/cu132. cu126 reached v3 before the others
# existed, which is why v4 was the first shared revision.
revision_tag="${IMAGE_REVISION:-v5}"

push=false
latest=false
no_cache=false
force=false

usage() {
  cat <<'EOF'
Usage: docker/build.sh [--cuda VARIANT] [--push] [--latest] [--no-cache] [--force]

Options:
  --cuda VAR   CUDA variant to build: cu126, cu129, cu130 or cu132.
               Default cu126. Selects the base image and the wheel index
               together, which is the only safe way to change CUDA version.
  --push       Push the versioned tag to Docker Hub after a successful build.
  --latest     Also tag and (with --push) publish :latest.
  --no-cache   Build without using the layer cache.
  --force      Allow overwriting a version tag that already exists remotely.
               Without it, --push --latest on an existing version tag moves
               only :latest and leaves the immutable version tag alone.
  -h, --help   Show this help.

Tags are composed as pt<torch>-<cuda>-<revision>, e.g. pt2.13.0-cu130-v1.

Environment overrides:
  DOCKER_NAMESPACE     Docker Hub namespace (default: leoxiao)
  IMAGE_NAME           Repository name (default: pytorch-dev)
  CUDA_VARIANT         Same as --cuda (default: cu126)
  IMAGE_REVISION       Revision suffix (default: v5)
  IMAGE_VERSION        Full tag, overriding the composed one
  TORCH_VERSION        PyTorch version (default: 2.13.0)
  TORCHVISION_VERSION  torchvision version (default: 0.28.0)
  CUDA_BASE            Override the base image for an unlisted CUDA version
  TORCH_CUDA_INDEX     Override the wheel index; must match CUDA_BASE

Never re-push an existing version tag; bump IMAGE_REVISION instead so a tag
always identifies exactly one image.

Examples:
  docker/build.sh --cuda cu130 --push            # Blackwell-capable image
  IMAGE_REVISION=v6 docker/build.sh --push       # new revision of cu126
EOF
}

while (($#)); do
  case "$1" in
    --cuda)
      shift
      cuda="${1:-}"
      [[ -n "$cuda" ]] || {
        echo "error: --cuda needs a value" >&2
        exit 2
      }
      ;;
    --push) push=true ;;
    --latest) latest=true ;;
    --no-cache) no_cache=true ;;
    --force) force=true ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

# Resolve the variant into a base image and a wheel index.
if [[ -n "${CUDA_BASE:-}" ]]; then
  cuda_base="$CUDA_BASE"
elif cuda_base="$(base_for_variant "$cuda")"; then
  :
else
  echo "error: unknown CUDA variant '$cuda'. Supported: $cuda_variants" >&2
  echo "For an unlisted version set both CUDA_BASE and TORCH_CUDA_INDEX." >&2
  exit 2
fi
torch_index="${TORCH_CUDA_INDEX:-https://download.pytorch.org/whl/${cuda}}"

version="${IMAGE_VERSION:-pt${torch_version}-${cuda}-${revision_tag}}"
tag="${namespace}/${image}:${version}"

if ! docker info >/dev/null 2>&1; then
  echo "error: no reachable Docker daemon. On macOS start one with: colima start --vm-type vz --vz-rosetta" >&2
  exit 1
fi

push_version=true

# Check credentials and tag immutability before the build, not after: on an
# emulated amd64 build that is half an hour of wasted work.
if $push; then
  if ! grep -q 'index.docker.io' "${DOCKER_CONFIG:-$HOME/.docker}/config.json" 2>/dev/null; then
    echo "error: not logged in to Docker Hub. Run: docker login" >&2
    exit 1
  fi

  if ! $force; then
    if manifest_out="$(docker manifest inspect "$tag" 2>&1)"; then
      if $latest; then
        echo "note: $tag already exists remotely; it will not be re-pushed." >&2
        echo "      Only :latest will be moved. Bump IMAGE_VERSION to publish a new image." >&2
        push_version=false
      else
        echo "error: $tag already exists on the registry." >&2
        echo "Published tags must stay immutable so a job always gets the same image." >&2
        echo "Bump IMAGE_VERSION, or pass --force if you really mean to overwrite it." >&2
        exit 1
      fi
    elif ! grep -qiE 'manifest unknown|manifest_unknown|not found|no such manifest|does not exist' <<<"$manifest_out"; then
      # Fail closed: a network error must not be mistaken for "tag is free".
      echo "error: could not determine whether $tag already exists:" >&2
      echo "$manifest_out" >&2
      echo "Refusing to push. Retry when the registry is reachable, or pass --force." >&2
      exit 1
    fi
  fi
fi

revision="$(git -C "$repo_dir" rev-parse --short HEAD 2>/dev/null || echo unknown)"
# --porcelain also catches untracked files; `git diff HEAD` would not.
if [[ -n "$(git -C "$repo_dir" status --porcelain 2>/dev/null)" ]]; then
  revision="${revision}-dirty"
fi

build_args=(build --platform "$platform" -f "$repo_dir/docker/Dockerfile" -t "$tag")
build_args+=(--build-arg "IMAGE_VERSION=$version" --build-arg "SOURCE_REVISION=$revision")
build_args+=(--build-arg "CUDA_BASE=$cuda_base" --build-arg "TORCH_CUDA_INDEX=$torch_index")
build_args+=(--build-arg "TORCH_VERSION=$torch_version" --build-arg "TORCHVISION_VERSION=$torchvision_version")
$no_cache && build_args+=(--no-cache)
$latest && build_args+=(-t "${namespace}/${image}:latest")
build_args+=("$repo_dir")

echo "Building $tag for $platform"
echo "  base  : $cuda_base"
echo "  wheels: $torch_index (torch $torch_version, torchvision $torchvision_version)"
docker "${build_args[@]}"

echo
docker images --format 'built: {{.Repository}}:{{.Tag}} ({{.Size}})' "${namespace}/${image}" | head -5

if $push; then
  if $push_version; then
    echo
    echo "Pushing $tag"
    docker push "$tag"
  fi
  if $latest; then
    echo
    echo "Pushing ${namespace}/${image}:latest"
    docker push "${namespace}/${image}:latest"
  fi
  echo
  echo "Verify on a GPU node with:"
  echo "  docker run --rm --gpus all --shm-size=8g $tag \\"
  echo "    python /opt/dotfiles/docker/verify-gpu.py"
fi
