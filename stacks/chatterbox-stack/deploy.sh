#!/bin/bash
# Chatterbox Audiobook Generator - Deploy Script
# Builds the Docker image locally and deploys to Docker Swarm

set -e

STACK_NAME="chatterbox-stack"
IMAGE_NAME="chatterbox-audiobook:local"
COMPOSE_FILE="docker-compose.yml"

echo "🔨 Building Docker image: $IMAGE_NAME"
docker build -t "$IMAGE_NAME" .

echo "🚀 Deploying stack: $STACK_NAME"
docker stack deploy -c "$COMPOSE_FILE" "$STACK_NAME"

echo "✅ Deployment complete!"
echo ""
echo "To check status:"
echo "  docker service ps ${STACK_NAME}_chatterbox-audiobook"
echo ""
echo "To view logs:"
echo "  docker service logs -f ${STACK_NAME}_chatterbox-audiobook"
echo ""
echo "Access at: http://192.168.31.75:7861"
