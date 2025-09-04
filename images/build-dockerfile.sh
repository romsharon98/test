#!/bin/bash
set -e

# Usage: ./build-dockerfile.sh <image-name> [--region <region>] [--tag <tag>] [--push]
# Examples:
#   ./build-dockerfile.sh llm-d                              # Build only
#   ./build-dockerfile.sh llm-d --push                       # Build and push
#   ./build-dockerfile.sh llm-d --region us-west-2 --push    # Build and push to specific region
#   ./build-dockerfile.sh llm-d --region us-east-1 --tag v1.0.0 --push  # Build and push with specific tag

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

ECR_REPO_PREFIX="impala/"   # Set your ECR repo name
IMPALA_CUSTOMER_ECR_REPO_PREFIX="impala/customer/"

# Parse arguments
IMAGE_NAME="$1"
AWS_REGION="us-east-1"  # Default
TAG="latest"            # Default
PUSH_FLAG=""

shift  # Remove image name from arguments

while [[ $# -gt 0 ]]; do
  case $1 in
    --region)
      AWS_REGION="$2"
      shift 2
      ;;
    --tag)
      TAG="$2"
      shift 2
      ;;
    --push)
      PUSH_FLAG="--push"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Only get AWS account ID if we're going to push
if [ -n "$PUSH_FLAG" ]; then
  AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
else
  AWS_ACCOUNT_ID="000000000000"  # Dummy value for local builds
fi

# Set build parameters based on argument
if [ "$IMAGE_NAME" == "llm-d" ]; then
  DOCKERFILE_PATH="$SCRIPT_DIR/Dockerfiles/llm-d-dockerfile"
  IMAGE_NAME="llm-d"
  ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$IMPALA_CUSTOMER_ECR_REPO_PREFIX$IMAGE_NAME:$TAG"
  BUILD_CONTEXT="$SCRIPT_DIR"
elif [ "$IMAGE_NAME" == "workload-runner" ]; then
  DOCKERFILE_PATH="$SCRIPT_DIR/../runner/Dockerfile"
  IMAGE_NAME="workload-runner"
  ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$IMPALA_CUSTOMER_ECR_REPO_PREFIX$IMAGE_NAME:$TAG"
  BUILD_CONTEXT="$SCRIPT_DIR/.."
elif [ "$IMAGE_NAME" == "batch-monitor" ]; then
  DOCKERFILE_PATH="$SCRIPT_DIR/../impalaai/Dockerfile.batch-monitor"
  IMAGE_NAME="batch-monitor"
  ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$IMPALA_CUSTOMER_ECR_REPO_PREFIX$IMAGE_NAME:$TAG"
  BUILD_CONTEXT="$SCRIPT_DIR/.."
elif [ "$IMAGE_NAME" == "mock-client" ]; then
  DOCKERFILE_PATH="$SCRIPT_DIR/Dockerfiles/mock-client/Dockerfile"
  IMAGE_NAME="mock-client"
  ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$IMPALA_CUSTOMER_ECR_REPO_PREFIX$IMAGE_NAME:$TAG"
  BUILD_CONTEXT="$SCRIPT_DIR/.."
elif [ "$IMAGE_NAME" == "metrics-collector" ]; then
  DOCKERFILE_PATH="$SCRIPT_DIR/../monitoring/Dockerfile.metrics_collector"
  IMAGE_NAME="metrics-collector"
  ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$IMPALA_CUSTOMER_ECR_REPO_PREFIX$IMAGE_NAME:$TAG"
  BUILD_CONTEXT="$SCRIPT_DIR/../monitoring"
elif [ "$IMAGE_NAME" == "infrastructure-monitoring" ]; then
  DOCKERFILE_PATH="$SCRIPT_DIR/../impalaai/Dockerfile.infrastructure_monitoring"
  IMAGE_NAME="infrastructure-monitoring"
  ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_PREFIX$IMAGE_NAME:$TAG"
  BUILD_CONTEXT="$SCRIPT_DIR/.."
else
  echo "Usage: $0 [image-name] [aws-region] [tag]"
  exit 1
fi

# Check required parameters
if [ -z "$DOCKERFILE_PATH" ] || [ -z "$IMAGE_NAME" ] || [ -z "$ECR_URI" ]; then
  echo "[ERROR] Required build parameters are not set."
  exit 1
fi

echo "[INFO] Building Docker image from $DOCKERFILE_PATH for linux/amd64..."

if [ -n "$PUSH_FLAG" ]; then
  echo "[INFO] Logging in to ECR..."
  aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
fi

docker buildx build --platform=linux/amd64 --provenance=false -t $ECR_URI -f $DOCKERFILE_PATH $BUILD_CONTEXT $PUSH_FLAG

if [ -n "$PUSH_FLAG" ]; then
  echo "[SUCCESS] Image built and pushed: $ECR_URI"
else
  echo "[SUCCESS] Image built locally: $IMAGE_NAME:$TAG"
fi