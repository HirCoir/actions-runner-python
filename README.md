# GitHub Actions Self-Hosted Runner - Python Edition

A Docker-based GitHub Actions self-hosted runner optimized for Python development with common tools and packages pre-installed.

## Features

- **Multi-stage Docker build** for optimized image size
- **Python 3.x** with pip, venv, and development tools
- **Common Python packages** pre-installed (requests, pytest, black, flake8, numpy, pandas, etc.)
- **Node.js and npm** for JavaScript/TypeScript projects
- **Docker CLI** for containerized workflows
- **Configurable via environment variables**
- **Automatic runner registration and startup**

## Quick Start

### 1. Get Runner Token

1. Go to your GitHub repository
2. Navigate to **Settings** > **Actions** > **Runners**
3. Click **"New self-hosted runner"**
4. Copy the token from the configuration command

### 2. Configure Environment

Copy the example environment file and fill in your values:

```bash
cp .env.example .env
```

Edit `.env` with your configuration:

```bash
GITHUB_URL=https://github.com/YourUsername/your-repo
GITHUB_TOKEN=your_runner_token_here
RUNNER_NAME=python-runner
RUNNER_LABELS=self-hosted,python,docker
```

### 3. Run with Docker Compose

```bash
docker-compose up -d
```

### 4. Run with Docker

```bash
docker build -t github-runner-python .

docker run -d \
  --name github-runner-python \
  -e GITHUB_URL="https://github.com/YourUsername/your-repo" \
  -e GITHUB_TOKEN="your_token_here" \
  -e RUNNER_NAME="python-runner" \
  -e RUNNER_LABELS="self-hosted,python,docker" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  github-runner-python
```

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `GITHUB_URL` | Yes | - | GitHub repository or organization URL |
| `GITHUB_TOKEN` | Yes | - | Runner registration token |
| `RUNNER_NAME` | No | hostname | Custom name for the runner |
| `RUNNER_LABELS` | No | `self-hosted,python,docker` | Comma-separated labels |
| `RUNNER_GROUP` | No | `default` | Runner group (for organizations) |
| `RUNNER_WORK_DIR` | No | `_work` | Working directory for jobs |

## Using in Workflows

Add this to your GitHub Actions workflow file (`.github/workflows/your-workflow.yml`):

```yaml
name: Python CI

on: [push, pull_request]

jobs:
  test:
    runs-on: self-hosted  # or use specific labels: [self-hosted, python]
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install -r requirements.txt
    
    - name: Run tests
      run: |
        python -m pytest
    
    - name: Run linting
      run: |
        black --check .
        flake8 .
```

## Pre-installed Python Packages

### Development Tools
- pytest
- black
- flake8
- mypy
- pylint

### Common Libraries
- requests
- pyyaml
- python-dotenv
- click

### Data Science
- numpy
- pandas
- matplotlib

### Web Frameworks
- flask
- fastapi

## Docker-in-Docker Support

The runner includes Docker CLI and can access the host Docker daemon via mounted socket. This enables:

- Building Docker images in workflows
- Running containerized tests
- Multi-container setups

## Troubleshooting

### Check runner status
```bash
docker logs github-actions-runner-python
```

### Access runner shell
```bash
docker exec -it github-actions-runner-python bash
```

### Remove and re-register runner
```bash
docker-compose down
docker-compose up -d
```

## Security Notes

- The runner runs with sudo privileges inside the container
- Docker socket is mounted for Docker-in-Docker functionality
- Consider running in privileged mode only if needed
- Keep your runner token secure and rotate regularly

## Customization

To add more Python packages or system tools, modify the Dockerfile:

```dockerfile
# Add more Python packages
RUN python3 -m pip install \
    your-package-here \
    another-package

# Add more system packages
RUN apt-get update && apt-get install -y \
    your-system-package \
    && rm -rf /var/lib/apt/lists/*
```

## License

This project is open source and available under the MIT License.
