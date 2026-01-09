#!/bin/bash
# Build script for fastapi-app with multi-architecture support

set -e

IMAGE_NAME="registry.internal.agaruda.io/agaruda/fastapi-app"
TAG="${1:-latest}"
PLATFORM="${2:-linux/amd64}"

echo "Building fastapi-app image..."
echo "Image: ${IMAGE_NAME}:${TAG}"
echo "Platform: ${PLATFORM}"
echo ""

# Build for specific platform (default: linux/amd64 for K8S nodes)
docker buildx build \
  --platform ${PLATFORM} \
  --tag ${IMAGE_NAME}:${TAG} \
  --load \
  .

echo ""
echo "✅ Build complete!"
echo ""
echo "To push to registry:"
echo "  docker push ${IMAGE_NAME}:${TAG}"
echo ""
echo "To build for multiple platforms:"
echo "  docker buildx build --platform linux/amd64,linux/arm64 --tag ${IMAGE_NAME}:${TAG} --push ."

