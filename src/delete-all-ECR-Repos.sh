#!/bin/bash
set -e

AWS_REGION="us-east-1"
NAMESPACE="santonix"

SERVICES=(
  src  
  adservice
  cartservice
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

for SERVICE in "${SERVICES[@]}"; do
  REPO_NAME="${NAMESPACE}/${SERVICE}"

  echo "Deleting ECR repo: ${REPO_NAME}"

  aws ecr delete-repository \
    --repository-name "${REPO_NAME}" \
    --region "${AWS_REGION}" \
    --force || echo "Repo ${REPO_NAME} not found"
done

echo "✅ Cleanup complete"
