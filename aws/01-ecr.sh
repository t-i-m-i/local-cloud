#!/usr/bin/env bash
# Stage 1: ECR (Elastic Container Registry).
# ECR is AWS's storage for Docker images, like a private Docker Hub.
# ECS will later download the app image from here.
set -euo pipefail
cd "$(dirname "$0")/.."
source aws/env.sh

# Create the repository (a named shelf for versions of one image).
# "|| true" lets the script be re-run: it is fine if the repository exists.
aws ecr create-repository --repository-name "$ECR_REPO" >/dev/null 2>&1 || true

# Build the app image and give it the full ECR address as its name.
docker build -t "$ECR_HOST/$ECR_REPO:latest" .

# Log Docker in to the registry. ECR hands out a temporary password for this.
aws ecr get-login-password | docker login --username AWS --password-stdin "$ECR_HOST"

# Upload the image to the registry.
docker push "$ECR_HOST/$ECR_REPO:latest"

# Show what ECR now holds.
aws ecr list-images --repository-name "$ECR_REPO"
