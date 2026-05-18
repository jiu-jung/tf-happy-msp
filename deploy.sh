#!/usr/bin/env bash
set -euo pipefail

AUTO_APPROVE="${AUTO_APPROVE:-false}"

PROVIDER_EKS="provider-eks.tf"
PROVIDER_EKS_DISABLED="provider-eks.tf.disabled"

PROVIDER_FULL="provider-full.tf"
PROVIDER_FULL_DISABLED="provider-full.tf.disabled"

ENABLE_ADDONS="${ENABLE_ADDONS:-true}"
ENABLE_ALB_CONTROLLER="${ENABLE_ALB_CONTROLLER:-true}"
ENABLE_METRICS_SERVER="${ENABLE_METRICS_SERVER:-true}"

apply_args=()
if [[ "$AUTO_APPROVE" == "true" ]]; then
  apply_args+=("-auto-approve")
fi

echo "==> Phase 1: Create VPC and EKS cluster"

# Ensure provider-eks.tf is active
if [[ ! -f "$PROVIDER_EKS" && -f "$PROVIDER_EKS_DISABLED" ]]; then
  mv "$PROVIDER_EKS_DISABLED" "$PROVIDER_EKS"
fi

# Ensure provider-full.tf is disabled before the cluster exists
if [[ -f "$PROVIDER_FULL" ]]; then
  mv "$PROVIDER_FULL" "$PROVIDER_FULL_DISABLED"
fi

terraform init

terraform apply \
  -target=module.vpc \
  -target=module.eks \
  "${apply_args[@]}"

echo "==> Phase 2: Install EKS add-ons"

# Disable provider-eks.tf to avoid duplicate provider configuration
if [[ -f "$PROVIDER_EKS" ]]; then
  mv "$PROVIDER_EKS" "$PROVIDER_EKS_DISABLED"
fi

# Enable provider-full.tf after EKS has been created
if [[ ! -f "$PROVIDER_FULL" && -f "$PROVIDER_FULL_DISABLED" ]]; then
  mv "$PROVIDER_FULL_DISABLED" "$PROVIDER_FULL"
fi

terraform init

terraform apply \
  -var="enable_addons=${ENABLE_ADDONS}" \
  -var="enable_alb_controller=${ENABLE_ALB_CONTROLLER}" \
  -var="enable_metrics_server=${ENABLE_METRICS_SERVER}" \
  "${apply_args[@]}"

echo "==> Deployment completed"
