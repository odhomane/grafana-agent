# Grafana Kubernetes Monitoring Setup

An interactive script for deploying Grafana Kubernetes monitoring stack with comprehensive metrics collection and secure remote execution capabilities.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration Parameters](#configuration-parameters)
- [Installation Methods](#installation-methods)
- [What Gets Deployed](#what-gets-deployed)
- [Metrics Collected](#metrics-collected)
- [Security Features](#security-features)
- [Troubleshooting](#troubleshooting)
- [Post-Installation](#post-installation)
- [Uninstallation](#uninstallation)
- [Contributing](#contributing)

## 🌟 Overview

This script automates the deployment of Grafana's Kubernetes monitoring solution using Helm. It provides a comprehensive monitoring stack that collects cluster metrics, node metrics, and application metrics, then forwards them to Grafana Cloud.

### Key Benefits
- **Interactive Setup**: Guided configuration with input validation
- **Secure Execution**: Safe for remote execution via curl
- **Comprehensive Monitoring**: Full-stack Kubernetes observability
- **Production Ready**: Tuned metric collection for performance
- **Multi-Cloud**: Supports AWS, GCP, and Azure

## ✨ Features

- 🔒 **Secure remote execution** with input validation and confirmations
- 🎯 **Interactive prompts** with smart defaults and validation
- 🔍 **Dependency checking** for required tools
- 🌐 **Multi-cloud support** (AWS, GCP, Azure)
- 📊 **Optimized metrics collection** for performance
- 🧹 **Automatic cleanup** of sensitive configuration files
- 🎨 **Color-coded output** for better user experience
- ⚡ **Error handling** with detailed feedback

## 📦 Prerequisites

### Required Tools
- **kubectl** (configured and connected to your cluster)
- **helm** (v3.x recommended)
- **bash** (v4.0+)
- **curl** (for remote execution)

### Kubernetes Cluster
- Kubernetes 1.19+ cluster
- Cluster admin permissions
- Internet connectivity for pulling images

### Grafana Cloud
- Active Grafana Cloud account
- Prometheus endpoint credentials
- API key with metrics write permissions

## 🚀 Quick Start

### Method 1: Direct Remote Execution (Recommended)
```bash
curl -sSL https://raw.githubusercontent.com/odhomane/grafana-agent/main/setup-grafana-monitoring.sh | bash
```

### Method 2: Download and Execute
```bash
# Download the script
curl -sSL https://raw.githubusercontent.com/odhomane/grafana-agent/main/setup-grafana-monitoring.sh -o setup-grafana-monitoring.sh

# Make executable
chmod +x setup-grafana-monitoring.sh

# Run interactively
./setup-grafana-monitoring.sh
```

### Method 3: Clone Repository
```bash
git clone https://github.com/odhomane/grafana-agent.git
cd grafana-agent
chmod +x setup-grafana-monitoring.sh
./setup-grafana-monitoring.sh
```

## ⚙️ Configuration Parameters

The script will prompt you for the following information:

| Parameter | Description | Format | Example | Default |
|-----------|-------------|---------|---------|---------|
| **Cluster Name** | Unique identifier for your cluster | `^[a-zA-Z0-9-]+$` | `production-cluster-east` | *Required* |
| **Customer ID** | Your organization identifier | `^[a-zA-Z0-9]+$` | `W111` | *Required* |
| **Region** | Cloud provider region | `^[a-z0-9-]+$` | `us-east-1` | `us-east-1` |
| **Project ID** | Project or tenant identifier | `^[a-zA-Z0-9-]+$` | `tenant-abc123` | *Required* |
| **Cloud Platform** | Cloud provider | `AWS\|GCP\|Azure` | `AWS` | `AWS` |
| **Stage** | Deployment stage | `^[a-zA-Z0-9-]+$` | `production` | `preprod` |
| **Environment Type** | Environment classification | `^[a-zA-Z0-9-]+$` | `prod` | `prod` |
| **Grafana Username** | Grafana Cloud username/ID | `^[0-9]+$` | `526296` | *Required* |
| **Grafana Password** | Grafana Cloud API key/token | Any characters | `glc_eyJ...` | *Required* |

### Getting Grafana Credentials

1. **Login to Grafana Cloud**
   - Visit [grafana.com](https://grafana.com)
   - Navigate to your organization

2. **Create API Key**
   - Go to **Configuration** → **API Keys**
   - Click **New API Key**
   - Set role to **MetricsPublisher** or **Editor**
   - Copy the generated key

3. **Find Your Endpoint**
   - Go to **Configuration** → **Data Sources**
   - Select your Prometheus data source
   - Note the **Remote Write URL**

## 📥 Installation Methods

### Prerequisites Check
The script automatically verifies:
- ✅ kubectl is installed and configured
- ✅ helm is installed and accessible
- ✅ Kubernetes cluster connectivity
- ✅ Current cluster context

### Installation Flow
1. **Dependency Verification**: Checks required tools
2. **Cluster Connection**: Validates kubectl configuration
3. **Interactive Configuration**: Prompts for all parameters
4. **Configuration Review**: Shows summary before proceeding
5. **Helm Deployment**: Installs monitoring stack
6. **Cleanup Options**: Removes sensitive files

## 🗂️ What Gets Deployed

### Namespace
- `grafana-agent`: Dedicated namespace for monitoring components

### Components
- **Grafana Alloy**: Metrics collection and forwarding agent
- **Kube-State-Metrics**: Kubernetes object metrics
- **Node Exporter**: Node-level system metrics
- **Prometheus Operator**: CRD management
- **Auto-discovery**: Annotation-based service discovery

### Helm Chart
- **Chart**: `grafana/k8s-monitoring`
- **Release Name**: `grafana-k8s-monitoring`
- **Timeout**: 300 seconds with atomic installation

## 📊 Metrics Collected

### Cluster Metrics
- **Pod Resource Usage**: CPU/Memory requests and limits
- **Deployment Status**: Replica counts and availability
- **StatefulSet Status**: Ready/Current/Updated replicas
- **Job Status**: Success/Active/Failed job metrics
- **Persistent Volumes**: Storage capacity and access modes
- **Resource Quotas**: Namespace resource constraints

### Node Metrics
- **System Info**: Boot time, kernel version, hostname
- **CPU Metrics**: Usage per core, load averages
- **Memory Metrics**: Available, free, cached, buffers
- **Disk Metrics**: I/O statistics, filesystem usage
- **Network Metrics**: Bytes transmitted/received

### Kubernetes Objects
- **Namespaces**: Labels, annotations, status
- **Pods**: Labels, annotations, owner references, status
- **Services**: Service discovery information
- **Nodes**: Labels, capacity, status

### Custom Metrics
- **Application Metrics**: Via annotation-based discovery
- **Alloy Metrics**: Agent health and performance
- **Volume Stats**: Kubelet volume statistics

## 🔒 Security Features

### Input Validation
- **Regex Patterns**: All inputs validated against appropriate patterns
- **Required Fields**: Mandatory parameters enforced
- **Sensitive Data**: Password input hidden from terminal

### Safe Execution
- **Error Handling**: `set -euo pipefail` for strict error handling
- **Confirmation Prompts**: Multiple safety checkpoints
- **Cleanup on Exit**: Automatic removal of sensitive files
- **Non-Root Warning**: Alerts when running as root

### Credential Protection
- **Hidden Input**: Passwords not displayed in terminal
- **File Cleanup**: Configuration files removed after installation
- **Memory Only**: Sensitive data not persisted unnecessarily

## 🔧 Troubleshooting

### Common Issues

#### **kubectl not configured**
```bash
Error: Cannot connect to Kubernetes cluster
Solution: Configure kubectl with: kubectl config set-context <context>
```

#### **Missing dependencies**
```bash
Error: Missing required dependencies: helm
Solution: Install helm: curl https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz
```

#### **Invalid input format**
```bash
Error: Invalid input. Please try again.
Solution: Follow the format requirements shown in prompts
```

#### **Helm installation timeout**
```bash
Error: Failed to install Grafana K8s monitoring
Solutions:
- Check cluster resources: kubectl top nodes
- Verify internet connectivity
- Check image pull policies
- Increase timeout if needed
```

### Debugging Steps

1. **Check Cluster Status**
   ```bash
   kubectl cluster-info
   kubectl get nodes
   kubectl get pods --all-namespaces
   ```

2. **Verify Helm**
   ```bash
   helm version
   helm repo list
   helm list --all-namespaces
   ```

3. **Check Installation**
   ```bash
   kubectl get pods -n grafana-agent
   kubectl logs -n grafana-agent -l app.kubernetes.io/name=alloy-metrics
   helm status grafana-k8s-monitoring -n grafana-agent
   ```

4. **Network Connectivity**
   ```bash
   # Test Grafana Cloud connectivity
   curl -I https://prometheus-prod-10-prod-us-central-0.grafana.net
   ```

### Log Analysis
```bash
# Check agent logs
kubectl logs -n grafana-agent deployment/grafana-k8s-monitoring-alloy-metrics -f

# Check kube-state-metrics
kubectl logs -n grafana-agent deployment/grafana-k8s-monitoring-kube-state-metrics -f

# Check node-exporter
kubectl logs -n grafana-agent daemonset/grafana-k8s-monitoring-prometheus-node-exporter -f
```

## 📈 Post-Installation

### Verification Steps

1. **Check Pod Status**
   ```bash
   kubectl get pods -n grafana-agent
   # All pods should be Running
   ```

2. **Verify Metrics Flow**
   ```bash
   # Check alloy metrics endpoint
   kubectl port-forward -n grafana-agent svc/grafana-k8s-monitoring-alloy-metrics 12345:12345
   curl http://localhost:12345/metrics
   ```

3. **Grafana Cloud Dashboard**
   - Login to Grafana Cloud
   - Navigate to **Explore**
   - Query: `up{cluster="your-cluster-name"}`
   - Verify metrics are flowing

### Monitoring Health

```bash
# Monitor all components
kubectl get all -n grafana-agent

# Check resource usage
kubectl top pods -n grafana-agent

# View recent events
kubectl get events -n grafana-agent --sort-by='.lastTimestamp'
```

### Configuration Updates

To update configuration:
```bash
# Edit values file
helm get values grafana-k8s-monitoring -n grafana-agent > current-values.yaml

# Update configuration
helm upgrade grafana-k8s-monitoring grafana/k8s-monitoring \
  --namespace grafana-agent \
  --values current-values.yaml
```

## 🗑️ Uninstallation

### Complete Removal
```bash
# Remove Helm release
helm uninstall grafana-k8s-monitoring -n grafana-agent

# Remove namespace (optional)
kubectl delete namespace grafana-agent

# Remove CRDs (if no other installations)
kubectl delete crd alertmanagerconfigs.monitoring.coreos.com
kubectl delete crd alertmanagers.monitoring.coreos.com
kubectl delete crd podmonitors.monitoring.coreos.com
kubectl delete crd probes.monitoring.coreos.com
kubectl delete crd prometheuses.monitoring.coreos.com
kubectl delete crd prometheusrules.monitoring.coreos.com
kubectl delete crd servicemonitors.monitoring.coreos.com
kubectl delete crd thanosrulers.monitoring.coreos.com
```

### Selective Removal
```bash
# Keep namespace, remove only the release
helm uninstall grafana-k8s-monitoring -n grafana-agent

# Remove specific components
kubectl delete deployment grafana-k8s-monitoring-kube-state-metrics -n grafana-agent
```

## 🤝 Contributing

### Development Setup
```bash
git clone https://github.com/odhomane/grafana-agent.git
cd grafana-agent
chmod +x setup-grafana-monitoring.sh
```

### Testing
```bash
# Dry run (if supported)
./setup-grafana-monitoring.sh --dry-run

# Test in development cluster
kubectl config use-context dev-cluster
./setup-grafana-monitoring.sh
```

### Pull Request Process
1. Fork the repository
2. Create a feature branch
3. Test changes thoroughly
4. Update documentation
5. Submit pull request

### Reporting Issues
Please include:
- Kubernetes version
- Helm version
- Error messages
- Steps to reproduce
- Expected vs actual behavior

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/odhomane/grafana-agent/blob/main/LICENSE) file for details.

## 📞 Support

- **Documentation**: [Grafana K8s Monitoring](https://grafana.com/docs/grafana-cloud/kubernetes-monitoring/)
- **Issues**: [GitHub Issues](https://github.com/odhomane/grafana-agent/issues)
- **Community**: [Grafana Community](https://community.grafana.com/)

---

**⚠️ Important**: Always test in a development environment before deploying to production clusters. Keep your Grafana Cloud credentials secure and rotate them regularly.
