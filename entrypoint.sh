#!/bin/bash
set -e

# Cleanup function for graceful shutdown
cleanup() {
    echo "Shutting down runner gracefully..."
    if [ -f ".runner" ]; then
        echo "Removing runner registration..."
        ./config.sh remove --token "$GITHUB_TOKEN" || true
    fi
    exit 0
}

# Set up signal handlers for graceful shutdown
trap cleanup SIGTERM SIGINT SIGQUIT

# Check required environment variables
if [ -z "$GITHUB_URL" ]; then
    echo "Error: GITHUB_URL environment variable is required"
    exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GITHUB_TOKEN environment variable is required"
    exit 1
fi

# Set default runner name if not provided
if [ -z "$RUNNER_NAME" ]; then
    RUNNER_NAME=$(hostname)
fi

# Force cleanup any existing sessions first
echo "Cleaning up any existing runner sessions..."
./config.sh remove --token "$GITHUB_TOKEN" || true

# Wait a moment to ensure session cleanup
sleep 2

# Remove any leftover credential files
rm -f .credentials .credentials_rsaparams .runner || true

# Configure runner with ephemeral flag to prevent session conflicts
echo "Configuring GitHub Actions Runner..."
./config.sh \
    --url "$GITHUB_URL" \
    --token "$GITHUB_TOKEN" \
    --name "$RUNNER_NAME" \
    --work "$RUNNER_WORK_DIR" \
    --labels "$RUNNER_LABELS" \
    --runnergroup "$RUNNER_GROUP" \
    --unattended \
    --replace \
    --ephemeral

# Start runner
echo "Starting GitHub Actions Runner..."
exec ./run.sh
