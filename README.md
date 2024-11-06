# Self-Hosted GitHub Actions Runner in Kubernetes

A lightweight setup for running GitHub Actions workflows in your Kubernetes cluster using Docker-in-Docker (DinD).

## 🎯 Objectives
- Run GitHub Actions workflows in your own infrastructure
- Maintain control over runner environment and resources

## 🏗️ Architecture
![Architecture Diagram](https://raw.githubusercontent.com/Raihan-009/self-hosted-runner/refs/heads/main/self-hosted-runner.png)

The setup utilizes a Docker-in-Docker (DinD) approach with two main components:
1. **Runner Container**: Executes GitHub Actions workflows
2. **DinD Sidecar**: Provides isolated Docker environment

Key features:
- Shared volume for workflow workspace
- Automatic runner registration/deregistration
- Kubernetes-native deployment
- Isolated container runtime

## 📁 Project Structure
```
.
├── Dockerfile           # Main runner image
├── Dockerfile.nginx     # Sample nginx test image
├── Makefile            # Build and deployment commands
├── README.md           # This file
├── entrypoint.sh       # Runner startup script
└── runner.yml          # Kubernetes manifests
```

## 🔧 Quick Start

1. **Build and Push Runner Image**
```bash
make build   # Build runner image
make push    # Push to registry
```

2. **Setup Kubernetes Environment**
```bash
make namespace  # Create namespace
make secrets   # Configure GitHub secrets
make deploy    # Deploy runner
```

3. **Verify Deployment**
```bash
make pod       # Check pod status
```

## 🧪 Test Deployment

The project includes a sample nginx deployment for testing:
- Uses Alpine-based nginx image
- Serves a simple welcome page
- Exposed on port 80

## 🛠️ Makefile Commands

| Command | Description |
|---------|-------------|
| `make build` | Build runner image |
| `make push` | Push to Docker registry |
| `make image` | Import to k3s |
| `make namespace` | Create K8s namespace |
| `make secrets` | Set GitHub secrets |
| `make deploy` | Deploy runner |
| `make pod` | Check pod status |
| `make delete` | Remove deployment |

## 🔐 Security Model
- Runner operates in isolated namespace
- GitHub token used for runner registration
- DinD provides container isolation

## ⚡ Benefits
- **Control**: Full control over runner environment
- **Security**: Private network access
- **Scalability**: Kubernetes-native scaling

## ⚠️ Important Notes

- Update `GITHUB_PERSONAL_TOKEN` in Makefile before deployment
- Runner automatically registers with GitHub on startup
- Uses `poridhi/custom-runner:v1.1` as default image tag
- Runs in `host-runner` namespace

## 📚 References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Self-hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
