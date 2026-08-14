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
version="${IMAGE_VERSION:-pt2.13.0-cu126-v3}"
platform="linux/amd64"

push=false
latest=false
no_cache=false
force=false

usage() {
  cat <<'EOF'
Usage: docker/build.sh [--push] [--latest] [--no-cache] [--force]

Options:
  --push       Push the versioned tag to Docker Hub after a successful build.
  --latest     Also tag and (with --push) publish :latest.
  --no-cache   Build without using the layer cache.
  --force      Allow overwriting a version tag that already exists remotely.
               Without it, --push --latest on an existing version tag moves
               only :latest and leaves the immutable version tag alone.
  -h, --help   Show this help.

Environment overrides:
  DOCKER_NAMESPACE   Docker Hub namespace (default: leoxiao)
  IMAGE_NAME         Repository name (default: pytorch-dev)
  IMAGE_VERSION      Version tag (default: pt2.13.0-cu126-v3)
  CUDA_BASE          Override the base image (must match TORCH_CUDA_INDEX)
  TORCH_CUDA_INDEX   Override the PyTorch wheel index (selects the CUDA build)

Never re-push an existing version tag; bump IMAGE_VERSION instead so a tag
always identifies exactly one image.
EOF
}

while (($#)); do
  case "$1" in
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
# Moving CUDA versions requires changing the base and the wheel index together.
if [[ -n "${CUDA_BASE:-}" ]]; then
  build_args+=(--build-arg "CUDA_BASE=$CUDA_BASE")
fi
if [[ -n "${TORCH_CUDA_INDEX:-}" ]]; then
  build_args+=(--build-arg "TORCH_CUDA_INDEX=$TORCH_CUDA_INDEX")
fi
$no_cache && build_args+=(--no-cache)
$latest && build_args+=(-t "${namespace}/${image}:latest")
build_args+=("$repo_dir")

echo "Building $tag for $platform"
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
