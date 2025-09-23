#!/bin/bash
# Removed 'set -e' to prevent script from exiting on errors
# We want the container to stay alive no matter what

# Check required environment variables - but don't exit to keep container alive
if [ -z "$GITHUB_URL" ]; then
    echo "Warning: GITHUB_URL environment variable is not set. Runner may not work properly."
    GITHUB_URL="https://github.com/placeholder"
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "Warning: GITHUB_TOKEN environment variable is not set. Runner may not work properly."
    GITHUB_TOKEN="placeholder_token"
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
    ./config.sh remove --token "$GITHUB_TOKEN" 2>/dev/null || echo "Failed to remove existing registration, continuing..."
    
    echo "Configuring GitHub Actions Runner..."
    ./config.sh \
        --url "$GITHUB_URL" \
        --token "$GITHUB_TOKEN" \
        --name "$RUNNER_NAME" \
        --work "$RUNNER_WORK_DIR" \
        --labels "$RUNNER_LABELS" \
        --runnergroup "$RUNNER_GROUP" \
        --unattended \
        --replace 2>/dev/null || echo "Failed to configure runner, will retry later..."
}

# Function to start runner with restart logic
start_runner() {
    local attempt=1
    
    while true; do
        echo "Starting GitHub Actions Runner (attempt #$attempt)..."
        
        # Configure runner before each start
        configure_runner
        
        # Start the runner with error handling
        ./run.sh 2>/dev/null || echo "Runner command failed, will retry..."
        
        local exit_code=$?
        echo "Runner exited with code: $exit_code"
        
        # Never exit - always restart regardless of exit code
        echo "Runner will restart regardless of exit code to keep container alive..."
        
        echo "Runner crashed or exited unexpectedly. Restarting in $RESTART_DELAY seconds..."
        sleep $RESTART_DELAY
        
        attempt=$((attempt + 1))
    done
}

# Handle signals - but never exit to keep container alive
cleanup() {
    echo "Received shutdown signal. Attempting cleanup but keeping container alive..."
    ./config.sh remove --token "$GITHUB_TOKEN" 2>/dev/null || echo "Cleanup failed, continuing..."
    echo "Container will remain alive despite shutdown signal"
    # Don't exit - just continue running
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
