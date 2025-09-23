#!/bin/bash
set -e

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

# Set restart delay (default 10 seconds)
RESTART_DELAY=${RESTART_DELAY:-10}

# Function to configure runner
configure_runner() {
    echo "Removing any existing runner registration..."
    ./config.sh remove --token "$GITHUB_TOKEN" || true
    
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
}

# Function to start runner with restart logic
start_runner() {
    local attempt=1
    
    while true; do
        echo "Starting GitHub Actions Runner (attempt #$attempt)..."
        
        # Configure runner before each start
        configure_runner
        
        # Start the runner
        ./run.sh
        
        local exit_code=$?
        echo "Runner exited with code: $exit_code"
        
        # Never exit - always restart regardless of exit code
        echo "Runner will restart regardless of exit code to keep container alive..."
        
        echo "Runner crashed or exited unexpectedly. Restarting in $RESTART_DELAY seconds..."
        sleep $RESTART_DELAY
        
        attempt=$((attempt + 1))
    done
}

# Handle signals for graceful shutdown
cleanup() {
    echo "Received shutdown signal. Cleaning up..."
    ./config.sh remove --token "$GITHUB_TOKEN" || true
    exit 0
}

trap cleanup SIGTERM SIGINT

# Start the runner with restart logic and infinite fallback
start_runner

# Infinite fallback loop to ensure container never stops
echo "Main runner function ended unexpectedly. Starting infinite fallback loop..."
while true; do
    echo "Container is alive - $(date)"
    sleep 30
    
    # Try to restart the runner every 5 minutes
    if [ $(($(date +%s) % 300)) -eq 0 ]; then
        echo "Attempting to restart runner..."
        start_runner &
    fi
done
