#!/bin/bash
set -e

# Cleanup function to remove runner on exit
cleanup() {
    echo "Cleaning up runner registration..."
    if [ -f ".runner" ]; then
        ./config.sh remove --token "$GITHUB_TOKEN" || true
    fi
}

# Set trap to cleanup on exit
trap cleanup EXIT SIGTERM SIGINT

# Check required environment variables
if [ -z "$GITHUB_URL" ]; then
    echo "Error: GITHUB_URL environment variable is required"
    exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GITHUB_TOKEN environment variable is required"
    exit 1
fi

# Generate unique runner name if not provided
if [ -z "$RUNNER_NAME" ]; then
    RUNNER_NAME="$(hostname)-$(date +%s)-$$"
fi

# Remove any existing runner configuration files
echo "Cleaning up any existing runner configuration..."
rm -f .runner .credentials .credentials_rsaparams

# Remove existing runner if it exists (try multiple times)
echo "Removing any existing runner registration..."
for i in {1..3}; do
    ./config.sh remove --token "$GITHUB_TOKEN" && break || {
        echo "Attempt $i failed, retrying in 5 seconds..."
        sleep 5
    }
done || true

# Wait a moment for GitHub to process the removal
sleep 2

# Configure runner
echo "Configuring GitHub Actions Runner..."
./config.sh \
    --url "$GITHUB_URL" \
    --token "$GITHUB_TOKEN" \
    --name "$RUNNER_NAME" \
    --work "$RUNNER_WORK_DIR" \
    --labels "$RUNNER_LABELS" \
    --runnergroup "$RUNNER_GROUP" \
    --unattended \
    --replace

# Start runner
echo "Starting GitHub Actions Runner..."
exec ./run.sh
