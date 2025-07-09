#!/bin/bash
set -euo pipefail

echo "🔍 Reading service and environment config..."
SERVICE_DIR="${SERVICE_PATH:-.}"
SERVICE_YAML="${SERVICE_DIR}/.iac/service.yaml"
ENV_YAML="${SERVICE_DIR}/.iac/env/${ENVIRONMENT}.yaml"

if [[ ! -f "$SERVICE_YAML" ]] || [[ ! -f "$ENV_YAML" ]]; then
  echo "❌ Missing .iac YAML files"
  exit 1
fi

SERVICE_NAME=$(yq '.service.name' "$SERVICE_YAML")
SERVICE_TYPE=$(yq '.service.type' "$SERVICE_YAML")
ENTRY_POINT=$(yq -o=json '.service.entry_point // []' "$SERVICE_YAML")
CPU=$(yq '.service.cpu // 256' "$SERVICE_YAML")
MEMORY=$(yq '.service.memory // 512' "$SERVICE_YAML")
PLATFORM_VERSION=$(yq '.service.platform_version // "LATEST"' "$SERVICE_YAML")

PORT=$(yq '.port // 8080' "$ENV_YAML")
AUTOSCALE=$(yq '.autoscale // false' "$ENV_YAML")
TASK_COUNT=$(yq -o=json '.task_count // {"min":1,"max":1}' "$ENV_YAML")
ENV_VARS=$(yq -o=json '.env_vars // {}' "$ENV_YAML")
SECRETS=$(yq -o=json '.secrets // {}' "$ENV_YAML")
TAGS=$(yq -o=json '.tags // {}' "$ENV_YAML")
HEALTH_CHECK=$(yq -o=json '.health_check // null' "$ENV_YAML")

echo "📥 Downloading platform outputs from S3..."
S3_KEY="qubit-infrastructure-state/platform/${ENVIRONMENT}/platform_outputs.json"
aws s3 cp "s3://${S3_KEY}" platform_outputs.json

VPC_ID=$(jq -r '.vpc_id' platform_outputs.json)
SUBNET_IDS=$(jq -c '.subnet_ids' platform_outputs.json)
SG_IDS=$(jq -c '.security_group_ids' platform_outputs.json)
CLUSTER_ARN=$(jq -r '.cluster_arn' platform_outputs.json)
NAMESPACE=$(jq -r '.cloudmap_namespace' platform_outputs.json)
ALB_ARN=$(jq -r '.alb_arn // ""' platform_outputs.json)
LISTENER_ARN=$(jq -r '.alb_listener_arn // ""' platform_outputs.json)
ZONE_ID=$(jq -r '.route53_zone_id // ""' platform_outputs.json)

echo "🧱 Writing Terraform module wrapper (main.tf)..."
cat > "${SERVICE_DIR}/.iac/main.tf" <<EOF
module "ecs_service" {  
  source = "git::https://github.com/nehamic-tech/iac-platform.git//modules/ecs-service?ref=main"
  name                 = "${SERVICE_NAME}"
  type                 = "${SERVICE_TYPE}"
  entry_point          = ${ENTRY_POINT}
  cpu                  = ${CPU}
  memory               = ${MEMORY}
  platform_version     = "${PLATFORM_VERSION}"
  port                 = ${PORT}
  autoscale            = ${AUTOSCALE}
  task_count           = ${TASK_COUNT}
  env_vars             = ${ENV_VARS}
  secrets              = ${SECRETS}
  tags                 = ${TAGS}
  health_check         = ${HEALTH_CHECK}
  image_uri            = "${IMAGE_URI}"
  environment          = "${ENVIRONMENT}"
  vpc_id               = "${VPC_ID}"
  subnet_ids           = ${SUBNET_IDS}
  security_group_ids   = ${SG_IDS}
  cluster_arn          = "${CLUSTER_ARN}"
  cloudmap_namespace   = "${NAMESPACE}"
  alb_arn              = "${ALB_ARN}"
  alb_listener_arn     = "${LISTENER_ARN}"
  route53_zone_id      = "${ZONE_ID}"
}
EOF

echo "🔧 Configuring backend..."
cat > "${SERVICE_DIR}/.iac/backend.tf" <<EOF
terraform {
  backend "s3" {}
}
EOF

cd "${SERVICE_DIR}/.iac"

echo "📦 Running terraform init..."
terraform init \
  -backend-config="bucket=qubit-infrastructure-state" \  
  -backend-config="key=services/${ENVIRONMENT}/${SERVICE_NAME}.tfstate" \
  -backend-config="region=${AWS_REGION}" \
  -backend-config="acl=bucket-owner-full-control"

echo "🚀 Running terraform apply..."
terraform apply -auto-approve

echo "🚀 cleaning up"
rm -f main.tf backend.tf platform_outputs.json
echo "✅ Done"
