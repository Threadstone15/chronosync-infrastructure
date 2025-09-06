#!/bin/bash
# Helper script to start the infrastructure with SSH agent forwarding
# For Linux/macOS environments

echo "Starting ChronoSync Infrastructure..."

# Check if .env exists
if [ ! -f .env ]; then
    echo "Creating .env from .env.example..."
    cp .env.example .env
    echo "Please edit .env with your MySQL credentials before continuing"
    exit 1
fi

# Export SSH_AUTH_SOCK for builder container
export SSH_AUTH_SOCK

# Start the infrastructure
docker compose up --build
