#!/bin/bash
set -e

AWS_ACCOUNT_ID="163447728448"
AWS_REGION="us-east-1"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
NAMESPACE="santonix"
VERSION="v1.0.0"

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
echo "Logging into AWS ECR..."
echo "========================================"

aws ecr get-login-password --region ${AWS_REGION} \
  | docker login --username AWS --password-stdin ${ECR_REGISTRY}

echo "Login successful ✅"

for SERVICE_PATH in "${SERVICES[@]}"; do
  SERVICE_NAME=$(basename "${SERVICE_PATH}")
  REPO_NAME="${NAMESPACE}/${SERVICE_NAME}"
  IMAGE="${ECR_REGISTRY}/${REPO_NAME}:${VERSION}"

  echo ""
  echo "----------------------------------------"
  echo "Service      : ${SERVICE_NAME}"
  echo "Image        : ${IMAGE}"
  echo "Build Context: ${SERVICE_PATH}"
  echo "----------------------------------------"

  # Create ECR repo if it does not exist
  aws ecr describe-repositories \
    --repository-names "${REPO_NAME}" \
    --region "${AWS_REGION}" >/dev/null 2>&1 || \
  aws ecr create-repository \
    --repository-name "${REPO_NAME}" \
    --region "${AWS_REGION}" >/dev/null

  docker build -t "${IMAGE}" "${SERVICE_PATH}"
  docker push "${IMAGE}"

  echo "✅ Pushed: ${IMAGE}"
done

echo ""
echo "🎉 All images successfully pushed to AWS ECR"


aws ecr delete-repository \
    --repository-name "${REPO_NAME}" \
    --region "${AWS_REGION}" >/dev/null
