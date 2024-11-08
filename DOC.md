# Hands-on Guide: Self-Hosted GitHub Actions Runner in Kubernetes

## Introduction
This guide provides step-by-step instructions for setting up a self-hosted GitHub Actions runner in Kubernetes using Docker-in-Docker (DinD). This setup allows you to run GitHub Actions workflows in your own infrastructure.

## Prerequisites
Before starting, ensure you have:
- A working Kubernetes cluster (k3s/kind/etc.)
- kubectl installed and configured
- Docker installed
- A GitHub account and repository
- A GitHub Personal Access Token (PAT)

## Step 1: Setting Up the Project Structure

1. Create a new directory for the project:
```bash
mkdir github-runner-k8s
cd github-runner-k8s
```

2. Create necessary files:
```bash
touch Dockerfile entrypoint.sh kubernetes.yaml
```

## Step 2: Creating the Dockerfile

The Dockerfile creates a container image that serves as our GitHub Actions runner environment. It creates a reproducible environment for the runner and installs necessary tools (Docker CLI, jq, etc.). It forms the base container image for the runner pod in Kubernetes

1. Create the Dockerfile with the following content:
```dockerfile
FROM debian:bookworm-slim
ARG RUNNER_VERSION="2.302.1"
ENV GITHUB_PERSONAL_TOKEN ""
ENV GITHUB_OWNER ""
ENV GITHUB_REPOSITORY ""

# Install Docker
RUN apt-get update && \
    apt-get install -y ca-certificates curl gnupg
RUN install -m 0755 -d /etc/apt/keyrings
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
RUN chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
RUN echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt-get update

# Install required packages
RUN apt-get install -y docker-ce-cli sudo jq

# Setup github user
RUN useradd -m github && \
    usermod -aG sudo github && \
    echo "%sudo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create directories with correct permissions
RUN mkdir -p /actions-runner && \
    chown -R github:github /actions-runner && \
    mkdir -p /work && \
    chown -R github:github /work

USER github
WORKDIR /actions-runner

# Download and install runner
RUN curl -Ls https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -o actions-runner.tar.gz && \
    tar xzf actions-runner.tar.gz && \
    rm actions-runner.tar.gz && \
    sudo ./bin/installdependencies.sh

COPY --chown=github:github entrypoint.sh /actions-runner/entrypoint.sh
RUN sudo chmod u+x /actions-runner/entrypoint.sh

ENTRYPOINT ["/actions-runner/entrypoint.sh"]
```

## Step 3: Creating the Entrypoint Script

The entrypoint script handles the runner's lifecycle - registration, execution, and cleanup. It automatically registers the runner with GitHub. It acts as the bridge between container and GitHub.

1. Create entrypoint.sh with the following content:
```bash
#!/bin/sh
registration_url="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPOSITORY}/actions/runners/registration-token"
echo "Requesting registration URL at '${registration_url}'"
payload=$(curl -sX POST -H "Authorization: token ${GITHUB_PERSONAL_TOKEN}" ${registration_url})
export RUNNER_TOKEN=$(echo $payload | jq .token --raw-output)

./config.sh \
    --name $(hostname) \
    --token ${RUNNER_TOKEN} \
    --labels my-runner \
    --url https://github.com/${GITHUB_OWNER}/${GITHUB_REPOSITORY} \
    --work "/work" \
    --unattended \
    --replace

remove() {
    ./config.sh remove --unattended --token "${RUNNER_TOKEN}"
}

trap 'remove; exit 130' INT
trap 'remove; exit 143' TERM

./run.sh "$*" &
wait $!
```

2. Make the script executable:
```bash
chmod +x entrypoint.sh
```

## Step 4: Creating the Kubernetes Deployment

This step defines how the runner should be deployed and managed in Kubernetes.

1. Create kubernetes.yaml with the following content:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: github-runner
  labels:
    app: github-runner
spec:
  replicas: 1
  selector:
    matchLabels:
      app: github-runner
  template:
    metadata:
      labels:
        app: github-runner
    spec:
      containers:
      - name: github-runner
        imagePullPolicy: Never
        image: github-runner:latest
        env:
        - name: GITHUB_OWNER
          valueFrom:
            secretKeyRef:
              name: github-secret
              key: GITHUB_OWNER
        - name: GITHUB_REPOSITORY
          valueFrom:
            secretKeyRef:
              name: github-secret
              key: GITHUB_REPOSITORY
        - name: GITHUB_PERSONAL_TOKEN
          valueFrom:
            secretKeyRef:
              name: github-secret
              key: GITHUB_PERSONAL_TOKEN
        - name: DOCKER_HOST
          value: tcp://localhost:2375
        volumeMounts:
        - name: data
          mountPath: /work/
      - name: dind
        image: docker:24.0.6-dind
        env:
        - name: DOCKER_TLS_CERTDIR
          value: ""
        resources:
          requests:
            cpu: 20m
            memory: 512Mi
        securityContext:
          privileged: true
        volumeMounts:
          - name: docker-graph-storage
            mountPath: /var/lib/docker
          - name: data
            mountPath: /work/
      volumes:
      - name: docker-graph-storage
        emptyDir: {}
      - name: data
        emptyDir: {}
```

## Step 5: Building and Loading the Image

1. Build the Docker image:
```bash
docker build . -t github-runner:latest
```

2. Load the image into your Kubernetes cluster:

For k3s:
```bash
# Save the image
docker save github-runner:latest -o github-runner.tar

# Import to k3s
sudo k3s ctr images import github-runner.tar
```

## Step 6: Creating GitHub Token

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token with following permissions:
   - repo (full control)
   - workflow
   - admin:org (if using organization repository)

## Step 7: Creating Kubernetes Secrets

1. Create namespace:
```bash
kubectl create namespace host-runner
```

2. Create secrets (replace placeholder values):
```bash
kubectl -n host-runner create secret generic github-secret \
  --from-literal=GITHUB_OWNER=<your-github-username> \
  --from-literal=GITHUB_REPOSITORY=<your-repo-name> \
  --from-literal=GITHUB_PERSONAL_TOKEN=<your-github-token>
```

## Step 8: Deploying to Kubernetes

1. Apply the Kubernetes deployment:
```bash
kubectl -n host-runner apply -f kubernetes.yaml
```

2. Verify the deployment:
```bash
# Check pod status
kubectl -n host-runner get pods

# Check runner logs
kubectl -n host-runner logs -f <pod-name> -c github-runner
```

## Step 9: Verifying the Setup

1. Go to your GitHub repository
2. Navigate to Settings → Actions → Runners
3. You should see your self-hosted runner listed and "Idle"

## Troubleshooting Guide

### Common Issues and Solutions

1. **Image Pull Error**
```bash
# Check if image is properly loaded
sudo crictl images | grep github-runner

# If not visible, reload the image
sudo k3s ctr images import github-runner.tar
```

2. **Permission Issues**
```bash
# Check pod logs
kubectl -n host-runner logs -f <pod-name> -c github-runner

# Verify secrets
kubectl -n host-runner get secrets github-secret -o yaml
```

3. **Runner Not Registering**
```bash
# Check if token is valid
kubectl -n host-runner logs <pod-name> -c github-runner | grep "Requesting registration URL"

# Verify network connectivity
kubectl -n host-runner exec <pod-name> -c github-runner -- curl -s https://api.github.com
```

## Cleanup Instructions

To remove the setup:

```bash
# Delete the deployment
kubectl -n host-runner delete -f kubernetes.yaml

# Delete the secrets
kubectl -n host-runner delete secret github-secret

# Delete the namespace
kubectl delete namespace host-runner

# Remove local images
docker rmi github-runner:latest
```

## Testing the Runner

1. Create a simple workflow in your repository:

```yaml
# .github/workflows/test.yml
name: Test Self-Hosted Runner
on: [push]
jobs:
  test:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v2
      - name: Test Runner
        run: |
          echo "Hello from self-hosted runner!"
          docker --version
```

2. Commit and push this file to your repository
3. Check the Actions tab in your repository to see the workflow running

## Maintenance Tips

1. **Updating Runner Version**:
   - Update RUNNER_VERSION in Dockerfile
   - Rebuild and redeploy

2. **Scaling Runners**:
   - Modify replicas in kubernetes.yaml
   - Apply changes with kubectl

3. **Monitoring**:
```bash
# Check runner status
kubectl -n host-runner get pods -w

# Check resource usage
kubectl -n host-runner top pod
```

Remember to:
- Regularly update the runner version
- Monitor resource usage
- Rotate GitHub tokens periodically
- Keep Docker images updated
