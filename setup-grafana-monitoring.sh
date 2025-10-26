#!/bin/bash

# Interactive Grafana K8s Monitoring Setup Script
# Safe for remote execution via: curl -sSL <url> | bash

set -euo pipefail  # Exit on error, undefined vars, pipe failures

usage() {
    cat <<'EOF'
Usage: setup-grafana-monitoring.sh [options]

Options:
  --help                Show this help message and exit
  --non-interactive     Require all configuration to be supplied via environment
                        variables or CLI flags. Prompts are disabled in this mode.
  --cluster-name VALUE  Grafana Agent cluster name (CLUSTER_NAME)
  --customer-id VALUE   Customer identifier (CUSTOMER_ID)
  --region VALUE        Deployment region (REGION)
  --project-id VALUE    Project identifier (PROJECT_ID)
  --cloud-platform VAL  Cloud platform name (CLOUD_PLATFORM)
  --stage VALUE         Stage identifier (STAGE)
  --env-type VALUE      Environment type (ENV_TYPE)
  --username VALUE      Grafana username (USERNAME)
  --password VALUE      Grafana password or token (PASSWORD)

All flags map to environment variables of the same name. Flags override
environment variables. In non-interactive mode every value must be provided.
EOF
}

NON_INTERACTIVE=${NON_INTERACTIVE:-false}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help)
            usage
            exit 0
            ;;
        --non-interactive)
            NON_INTERACTIVE=true
            shift
            ;;
        --cluster-name)
            export CLUSTER_NAME="$2"
            shift 2
            ;;
        --customer-id)
            export CUSTOMER_ID="$2"
            shift 2
            ;;
        --region)
            export REGION="$2"
            shift 2
            ;;
        --project-id)
            export PROJECT_ID="$2"
            shift 2
            ;;
        --cloud-platform)
            export CLOUD_PLATFORM="$2"
            shift 2
            ;;
        --stage)
            export STAGE="$2"
            shift 2
            ;;
        --env-type)
            export ENV_TYPE="$2"
            shift 2
            ;;
        --username)
            export USERNAME="$2"
            shift 2
            ;;
        --password)
            export PASSWORD="$2"
            shift 2
            ;;
        --*)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
        *)
            echo "Unexpected argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

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

# Function to get terminal input (fixes stdin issue with curl | bash)
get_tty_input() {
    if [[ -t 0 ]]; then
        # stdin is a terminal
        cat
    else
        # stdin is not a terminal (piped from curl), use /dev/tty
        cat < /dev/tty
    fi
}

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
            if [[ -t 0 ]]; then
                read -s input
            else
                read -s input < /dev/tty
            fi
            echo  # Add newline after hidden input
        else
            if [[ -t 0 ]]; then
                read input
            else
                read input < /dev/tty
            fi
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

# Function to obtain configuration values from environment/CLI or prompt
get_config_value() {
    local var_name="$1"
    local prompt="$2"
    local default_value="${3:-}"
    local validation_regex="${4:-.*}"
    local is_sensitive="${5:-false}"

    local env_value="${!var_name:-}"

    if [[ -n "$env_value" ]]; then
        if [[ "$env_value" =~ $validation_regex ]]; then
            eval "$var_name='$env_value'"
            if [[ "$is_sensitive" != "true" ]]; then
                print_info "Using $var_name from environment/CLI"
            else
                print_info "Using $var_name from environment/CLI (hidden)"
            fi
            return
        fi

        print_error "Value provided for $var_name does not match expected format: $validation_regex"
        exit 1
    fi

    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        print_error "$var_name is required in non-interactive mode. Provide it via environment variable or CLI flag."
        exit 1
    fi

    prompt_input "$prompt" "$var_name" "$default_value" "$validation_regex" "$is_sensitive"
}

# Function to confirm action
confirm_action() {
    local message="$1"
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        print_info "Non-interactive mode: automatically confirming '$message'."
        return
    fi
    echo -e "\n${YELLOW}$message${NC}"
    
    if [[ -t 0 ]]; then
        read -p "Do you want to continue? (y/N): " -n 1 -r
    else
        read -p "Do you want to continue? (y/N): " -n 1 -r < /dev/tty
    fi
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Operation cancelled."
        exit 0
    fi
}

# Check if running as root and handle appropriately
check_root_user() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root detected."
        print_info "While this script can run as root, it's generally safer to run as a regular user with sudo access."
        print_info "The script will automatically use appropriate permissions for file creation and kubectl operations."
        
        # Check if we're in a container or if this is intentional
        if [[ -f /.dockerenv ]] || [[ -n "${KUBERNETES_SERVICE_HOST:-}" ]]; then
            print_info "Container environment detected - running as root is acceptable."
        else
            echo -e "\n${YELLOW}Root execution warnings:${NC}"
            echo "• Files will be created with root ownership"
            echo "• kubectl operations will run as root"
            echo "• Consider running as regular user with kubectl access instead"
            
            confirm_action "Do you want to continue running as root?"
        fi
        
        # Set secure file permissions for root
        umask 077
    else
        print_info "Running as user: $(whoami)"
    fi
}

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
        
        # Provide installation hints based on user type
        if [[ $EUID -eq 0 ]]; then
            print_info "As root, you can typically install with your package manager:"
            echo "  • Ubuntu/Debian: apt-get update && apt-get install -y kubectl"
            echo "  • RHEL/CentOS: yum install -y kubectl"
            echo "  • Or download directly from Kubernetes releases"
        else
            print_info "Install options:"
            echo "  • Use your package manager (may require sudo)"
            echo "  • Download binaries to ~/bin or another PATH directory"
            echo "  • Use installation tools like brew, snap, or direct downloads"
        fi
        exit 1
    fi
}

# Function to detect cloud platform and adjust configuration
detect_and_configure_cloud() {
    local detected_platform=""
    
    # Try to detect cloud platform automatically
    if kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' 2>/dev/null | grep -q "azure://"; then
        detected_platform="Azure"
    elif kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' 2>/dev/null | grep -q "aws://"; then
        detected_platform="AWS"
    elif kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' 2>/dev/null | grep -q "gce://"; then
        detected_platform="GCP"
    fi
    
    if [[ -n "$detected_platform" ]]; then
        print_info "Detected cloud platform: $detected_platform"
        if [[ "$CLOUD_PLATFORM" != "$detected_platform" ]]; then
            print_warning "You specified '$CLOUD_PLATFORM' but detected '$detected_platform'"
            print_info "Using detected platform for optimal configuration."
            CLOUD_PLATFORM="$detected_platform"
        fi
    fi
}
check_k8s_connection() {
    print_info "Testing Kubernetes connection..."
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster."
        
        if [[ $EUID -eq 0 ]]; then
            print_info "Running as root - ensure kubectl config is properly set up."
            print_info "You may need to:"
            echo "  • Copy kubeconfig to /root/.kube/config"
            echo "  • Set KUBECONFIG environment variable"
            echo "  • Ensure cluster certificates are accessible"
        else
            print_info "Please ensure kubectl is configured correctly for your user."
            print_info "Check: kubectl config view"
        fi
        exit 1
    fi
    
    local context=$(kubectl config current-context)
    local user_info=""
    
    if [[ $EUID -eq 0 ]]; then
        user_info=" (as root)"
    fi
    
    print_info "Connected to Kubernetes context: $context$user_info"
    
    # Additional security check for root users
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running kubectl operations as root on cluster: $context"
        confirm_action "This will install Grafana monitoring with root privileges on the current cluster."
    else
        confirm_action "This will install Grafana monitoring on the current cluster."
    fi
}

# Create values file with appropriate permissions
create_values_file() {
    local values_file="values-$CLUSTER_NAME.yaml"
    
    print_info "Creating Helm values file: $values_file"
    
    # Create file with restricted permissions
    if [[ $EUID -eq 0 ]]; then
        # Root: create with 600 permissions (owner read/write only)
        touch "$values_file"
        chmod 600 "$values_file"
        print_info "File created with root ownership and 600 permissions."
    else
        # Regular user: create with default umask
        touch "$values_file"
        chmod 600 "$values_file"
        print_info "File created with user ownership and restricted permissions."
    fi
    
    cat <<EOF > "$values_file"
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

    print_success "Values file created successfully."
}

# Cleanup function with user-aware permissions
cleanup_values_file() {
    local values_file="values-$CLUSTER_NAME.yaml"
    
    if [[ -f "$values_file" ]]; then
        # Securely delete the file
        if command -v shred &> /dev/null; then
            print_info "Securely deleting values file with shred..."
            shred -vfz -n 3 "$values_file"
        else
            print_info "Deleting values file..."
            rm -f "$values_file"
        fi
        print_success "Values file deleted for security."
    fi
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
    
    # Gather inputs directly without checks
    echo -e "\n${BLUE}Configuration Parameters:${NC}"
    
    get_config_value CLUSTER_NAME "Cluster name" "" "^[a-zA-Z0-9-]+$"
    get_config_value CUSTOMER_ID "Customer ID" "" "^[a-zA-Z0-9]+$"
    get_config_value REGION "Region" "us-east-1" "^[a-z0-9-]+$"
    get_config_value PROJECT_ID "Project ID" "" "^[a-zA-Z0-9-]+$"
    get_config_value CLOUD_PLATFORM "Cloud platform" "AWS" "^[a-zA-Z0-9_-]+$"
    get_config_value STAGE "Stage" "preprod" "^[a-zA-Z0-9-]+$"
    get_config_value ENV_TYPE "Environment type" "prod" "^[a-zA-Z0-9-]+$"
    get_config_value USERNAME "Grafana username" "" "^[0-9]+$"
    get_config_value PASSWORD "Grafana password/token" "" ".*" true
    
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
    
    if [[ $EUID -eq 0 ]]; then
        echo "Running as: root"
    else
        echo "Running as: $(whoami)"
    fi
    
    # Create values file
    create_values_file
    
    # Perform checks after getting all inputs
    print_info "Checking dependencies..."
    check_dependencies
    print_success "All dependencies found."
    
    print_info "Checking Kubernetes connection..."
    check_k8s_connection
    
    confirm_action "Proceed with the installation using these settings?"
    
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
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        print_info "Non-interactive mode: deleting generated values file."
        cleanup_values_file
    else
        if [[ -t 0 ]]; then
            read -p "Do you want to delete the values file with sensitive information? (Y/n): " -n 1 -r
        else
            read -p "Do you want to delete the values file with sensitive information? (Y/n): " -n 1 -r < /dev/tty
        fi
        echo

        if [[ $REPLY =~ ^[Nn]$ ]]; then
            print_warning "Values file retained: values-$CLUSTER_NAME.yaml"
            if [[ $EUID -eq 0 ]]; then
                print_warning "File is owned by root with 600 permissions."
            fi
            print_warning "Remember to delete it manually to protect sensitive information."
        else
            cleanup_values_file
        fi
    fi
    
    echo -e "\n${GREEN}Installation completed successfully!${NC}"
    print_info "You can check the status with:"
    echo "  kubectl get pods -n grafana-agent"
    echo "  helm status grafana-k8s-monitoring -n grafana-agent"
    
    # Provide user-specific post-installation info
    if [[ $EUID -eq 0 ]]; then
        print_info "Root user notes:"
        echo "  • All kubectl operations were performed as root"
        echo "  • Consider setting up proper RBAC for regular users"
        echo "  • Files created in: $(pwd)"
    fi
}

# Enhanced cleanup function
cleanup() {
    local values_file="values-${CLUSTER_NAME:-temp}.yaml"
    if [[ -f "$values_file" ]]; then
        print_warning "Cleaning up values file on exit..."
        cleanup_values_file
    fi
}
trap cleanup EXIT

# Run main function
main "$@"
