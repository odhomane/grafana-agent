#!/bin/bash

# Interactive Grafana K8s Monitoring Setup Script
# Safe for remote execution via: curl -sSL <url> | bash

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to prompt for input with validation
prompt_input() {
    local prompt="$1"
    local var_name="$2"
    local default_value="${3:-}"
    local validation_regex="${4:-.*}"
    local is_sensitive="${5:-false}"
    
    while true; do
        if [[ -n "$default_value" ]]; then
            echo -n "$prompt [$default_value]: "
        else
            echo -n "$prompt: "
        fi
        
        if [[ "$is_sensitive" == "true" ]]; then
            read -s input
            echo  # Add newline after hidden input
        else
            read input
        fi
        
        # Use default if empty input
        if [[ -z "$input" && -n "$default_value" ]]; then
            input="$default_value"
        fi
        
        # Validate input
        if [[ "$input" =~ $validation_regex ]]; then
            eval "$var_name='$input'"
            break
        else
            print_error "Invalid input. Please try again."
        fi
    done
}

# Function to confirm action
confirm_action() {
    local message="$1"
    echo -e "\n${YELLOW}$message${NC}"
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Operation cancelled."
        exit 0
    fi
}

# Check if running as root (not recommended)
if [[ $EUID -eq 0 ]]; then
    print_warning "Running as root is not recommended for this script."
    confirm_action "Are you sure you want to continue as root?"
fi

# Check required tools
check_dependencies() {
    local deps=("kubectl" "helm")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_info "Please install them before running this script."
        exit 1
    fi
}

# Check kubectl connection
check_k8s_connection() {
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster."
        print_info "Please ensure kubectl is configured correctly."
        exit 1
    fi
    
    local context=$(kubectl config current-context)
    print_info "Connected to Kubernetes context: $context"
    confirm_action "This will install Grafana monitoring on the current cluster."
}

# Main script
main() {
    echo -e "${GREEN}"
    echo "=========================================="
    echo "  Grafana K8s Monitoring Setup Script   "
    echo "=========================================="
    echo -e "${NC}"
    
    print_info "This script will set up Grafana Kubernetes monitoring."
    print_info "Please provide the following information:"
    echo
    
    # Check dependencies first
    print_info "Checking dependencies..."
    check_dependencies
    print_success "All dependencies found."
    
    # Check Kubernetes connection
    print_info "Checking Kubernetes connection..."
    check_k8s_connection
    
    # Gather inputs
    echo -e "\n${BLUE}Configuration Parameters:${NC}"
    
    prompt_input "Cluster name" CLUSTER_NAME "" "^[a-zA-Z0-9-]+$"
    prompt_input "Customer ID" CUSTOMER_ID "" "^[a-zA-Z0-9]+$"
    prompt_input "Region" REGION "us-east-1" "^[a-z0-9-]+$"
    prompt_input "Project ID" PROJECT_ID "" "^[a-zA-Z0-9-]+$"
    prompt_input "Cloud platform" CLOUD_PLATFORM "AWS" "^(AWS|GCP|Azure)$"
    prompt_input "Stage" STAGE "preprod" "^[a-zA-Z0-9-]+$"
    prompt_input "Environment type" ENV_TYPE "prod" "^[a-zA-Z0-9-]+$"
    prompt_input "Grafana username" USERNAME "" "^[0-9]+$"
    prompt_input "Grafana password/token" PASSWORD "" ".*" true
    
    # Display configuration summary
    echo -e "\n${BLUE}Configuration Summary:${NC}"
    echo "Cluster Name: $CLUSTER_NAME"
    echo "Customer ID: $CUSTOMER_ID"
    echo "Region: $REGION"
    echo "Project ID: $PROJECT_ID"
    echo "Cloud Platform: $CLOUD_PLATFORM"
    echo "Stage: $STAGE"
    echo "Environment Type: $ENV_TYPE"
    echo "Username: $USERNAME"
    echo "Password: [HIDDEN]"
    
    confirm_action "Proceed with the installation using these settings?"
    
    # Create values file
    print_info "Creating Helm values file..."
    
    cat <<EOF > "values-$CLUSTER_NAME.yaml"
cluster:
  name: $CLUSTER_NAME
destinations:
  - name: metricsService
    type: prometheus
    url: https://prometheus-prod-10-prod-us-central-0.grafana.net/api/prom/push
    extraLabels:
      customer_id: $CUSTOMER_ID
      region: $REGION
      project_id: "$PROJECT_ID"
      cloud_platform: $CLOUD_PLATFORM
      stage: $STAGE
      env_type: $ENV_TYPE
    auth:
      type: basic
      username: "$USERNAME"
      password: "$PASSWORD"

clusterMetrics:
  enabled: true
  kube-state-metrics:
    metricLabelsAllowlist:
      - pods=[*]
      - namespaces=[*]
    metricAnnotationsAllowlist:
      - pods=[*]
      - namespaces=[*]
    deploy: true
    metricsTuning:
      useDefaultAllowList: false
      includeMetrics:
        - cluster:namespace:pod_cpu:active:kube_pod_container_resource_limits
        - cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests
        - cluster:namespace:pod_memory:active:kube_pod_container_resource_limits
        - cluster:namespace:pod_memory:active:kube_pod_container_resource_requests
        - kube_deployment_status_replicas_available
        - kube_statefulset_status_replicas_ready
        - kube_statefulset_status_replicas
        - kube_statefulset_status_replicas_current
        - kube_statefulset_status_replicas_updated
        - kube_statefulset_status_replicas_desired
        - kube_replicaset_status_ready_replicas
        - kube_daemonset_status_number_ready
        - kube_persistentvolume_status_phase
        - kube_persistentvolumeclaim_access_mode
        - kube_persistentvolumeclaim_resource_requests_storage_bytes
        - kube_namespace_labels
        - kube_namespace_status_phase
        - kube_namespace_annotations
        - kube_node_info
        - kube_node_labels
        - kube_node_status_capacity
        - kube_pod_container_status_last_terminated_reason
        - kube_pod_container_status_running
        - kube_pod_container_status_waiting_reason
        - kube_pod_info
        - kube_pod_owner
        - kube_pod_labels
        - kube_pod_annotations
        - kube_pod_status_phase
        - kube_pod_container_resource_requests
        - kube_pod_container_resource_limits
        - kube_pod_container_resource_requests_cpu_cores
        - kube_pod_container_resource_requests_memory_bytes
        - kube_pod_container_resource_limits_cpu_cores
        - kube_pod_container_resource_limits_memory_bytes
        - kube_job_status_succeeded
        - kube_job_status_active
        - kube_job_status_failed
        - kube_resourcequota
        - kube_service_info
        - kube_service_spec_type

  opencost:
    enabled: false

  kubelet:
    metricsTuning:
      useDefaultAllowList: false
      includeMetrics:
        - kubelet_node_name
        - kubernetes_build_info
        - kubelet_volume_stats_available_bytes
        - kubelet_volume_stats_capacity_bytes

  node-exporter:
    enabled: true
    metricsTuning:
      useDefaultAllowList: false
      includeMetrics:
        - node_boot_time_seconds
        - node_uname_info
        - node_cpu_seconds_total
        - node_load1
        - node_load5
        - node_load15
        - node_disk_io_time_seconds_total
        - node_disk_read_bytes_total
        - node_disk_written_bytes_total
        - node_filesystem_avail_bytes
        - node_filesystem_size_bytes
        - node_filesystem_files
        - node_filesystem_files_free
        - node_memory_Buffers_bytes
        - node_memory_MemAvailable_bytes
        - node_memory_Cached_bytes
        - node_memory_MemFree_bytes
        - node_memory_MemTotal_bytes
        - node_network_receive_bytes_total
        - node_network_transmit_bytes_total

alloy-metrics:
  enabled: true

annotationAutodiscovery:
  enabled: true

prometheusOperatorObjects:
  enabled: true
  crds:
    deploy: true

integrations:
  alloy:
    instances:
      - name: alloy
        labelSelectors:
          app.kubernetes.io/name:
            - alloy-metrics
        metrics:
          tuning:
            useDefaultAllowList: false
            includeMetrics:
              - alloy_build_info
EOF

    print_success "Values file created: values-$CLUSTER_NAME.yaml"
    
    # Add Helm repo and install
    print_info "Adding Grafana Helm repository..."
    if helm repo add grafana https://grafana.github.io/helm-charts; then
        print_success "Grafana Helm repo added."
    else
        print_error "Failed to add Grafana Helm repo."
        exit 1
    fi
    
    print_info "Updating Helm repositories..."
    if helm repo update; then
        print_success "Helm repositories updated."
    else
        print_error "Failed to update Helm repositories."
        exit 1
    fi
    
    print_info "Installing Grafana K8s monitoring..."
    print_warning "This may take a few minutes..."
    
    if helm upgrade --install --atomic --timeout 300s grafana-k8s-monitoring grafana/k8s-monitoring \
        --namespace grafana-agent \
        --create-namespace \
        --values "values-$CLUSTER_NAME.yaml"; then
        print_success "Grafana K8s monitoring installed successfully!"
    else
        print_error "Failed to install Grafana K8s monitoring."
        print_info "Check the Helm output above for details."
        exit 1
    fi
    
    # Cleanup option
    echo
    read -p "Do you want to delete the values file with sensitive information? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_warning "Values file retained: values-$CLUSTER_NAME.yaml"
        print_warning "Remember to delete it manually to protect sensitive information."
    else
        rm "values-$CLUSTER_NAME.yaml"
        print_success "Values file deleted for security."
    fi
    
    echo -e "\n${GREEN}Installation completed successfully!${NC}"
    print_info "You can check the status with:"
    echo "  kubectl get pods -n grafana-agent"
    echo "  helm status grafana-k8s-monitoring -n grafana-agent"
}

# Trap to cleanup on exit
cleanup() {
    if [[ -f "values-$CLUSTER_NAME.yaml" ]]; then
        print_warning "Cleaning up values file..."
        rm -f "values-$CLUSTER_NAME.yaml"
    fi
}
trap cleanup EXIT

# Run main function
main "$@"