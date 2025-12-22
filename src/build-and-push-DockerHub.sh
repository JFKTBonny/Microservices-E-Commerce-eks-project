#!/bin/bash

set -e

REGISTRY="santonix"
VERSION=${1:-v1.0.0} # Pass version dynamically...

SERVICES=(
  adservice
  cartservice/src
  checkoutservice
  currencyservice
  emailservice
  frontend
  loadgenerator
  paymentservice
  productcatalogservice
  recommendationservice
  shippingservice
)

echo "========================================"
echo "Docker Hub Registry : ${REGISTRY}"
echo "Image Version       : ${VERSION}"
echo "========================================"

for SERVICE_PATH in "${SERVICES[@]}"; do
  SERVICE_NAME=$(basename "$SERVICE_PATH")
  IMAGE="${REGISTRY}/${SERVICE_NAME}:${VERSION}"

  echo ""
  echo "🚀 Building ${IMAGE}"
  docker build -t "${IMAGE}" "${SERVICE_PATH}"

  echo "📤 Pushing ${IMAGE}"
  docker push "${IMAGE}"

  echo "✅ Done: ${IMAGE}"
done

echo ""
echo "🎉 All images successfully pushed to Docker Hub"
