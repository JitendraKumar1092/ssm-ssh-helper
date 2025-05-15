#!/bin/bash
# filepath: ~/ssm-ssh-proxy.sh

NAME="$1"
REGION="ap-south-1"

# Lookup instance ID by Name tag
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$NAME" "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text --region "$REGION")

if [ -z "$INSTANCE_ID" ]; then
  echo "No running instance found with Name tag: $NAME" >&2
  exit 1
fi

# Start SSM session as ssm-user (not SSH)
exec aws ssm start-session --target "$INSTANCE_ID" --region "$REGION"
