#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../terraform"
INVENTORY=../ansible/inventory.ini

APP_IPS=$(terraform output -json instance_public_ips | jq -r '.[]')
MONITORING_IP=$(terraform output -json monitoring_public_ip | jq -r 'select(. != null)')

if [ -z "$APP_IPS" ]; then
  echo "Error: No app hosts found. Terraform output may be empty." >&2
  exit 1
fi

{
  echo "[app]"
  for ip in $APP_IPS; do echo "$ip ansible_user=ec2-user"; done

  if [ -n "$MONITORING_IP" ]; then
    echo
    echo "[monitoring]"
    echo "$MONITORING_IP ansible_user=ec2-user"
  fi
} > "$INVENTORY"

echo "Inventory built:"
cat "$INVENTORY"
