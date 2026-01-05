#!/bin/bash
#
# Script to deploy the Red Hat UBI-based no-vscode editor definition
# that prevents VS Code from starting in OpenShift Dev Spaces (Eclipse Che)
#
# Based on: https://eclipse.dev/che/docs/stable/administration-guide/configuring-editors-definitions/
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="${DEVSPACES_NAMESPACE:-openshift-devspaces}"
EDITOR_DEFINITION_FILE="no-vscode-editor-definition.yaml"
CONFIGMAP_NAME="no-vscode-editor-definition"
EDITOR_ID="redhat-custom/no-vscode/1.0.0"

# Print functions
print_header() {
    echo -e "${BLUE}=======================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=======================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "  $1"
}

# Usage function
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Deploy or remove the no-vscode editor definition for OpenShift Dev Spaces"
    echo ""
    echo "Options:"
    echo "  -n, --namespace NAMESPACE   Target namespace (default: openshift-devspaces)"
    echo "  -d, --delete                Remove the editor definition"
    echo "  -v, --verify                Verify the deployment only"
    echo "  -h, --help                  Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  DEVSPACES_NAMESPACE         Alternative way to set the namespace"
    echo ""
    echo "Examples:"
    echo "  $0                          Deploy to default namespace"
    echo "  $0 -n eclipse-che           Deploy to eclipse-che namespace"
    echo "  $0 --delete                 Remove the editor definition"
    echo "  $0 --verify                 Check if deployment is active"
}

# Parse arguments
DELETE_MODE=false
VERIFY_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -d|--delete)
            DELETE_MODE=true
            shift
            ;;
        -v|--verify)
            VERIFY_MODE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Check for required tools
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    if ! command -v kubectl &> /dev/null && ! command -v oc &> /dev/null; then
        print_error "Neither kubectl nor oc command found"
        echo "Please install kubectl or the OpenShift CLI (oc)"
        exit 1
    fi
    
    # Prefer oc if available
    if command -v oc &> /dev/null; then
        KUBECTL="oc"
        print_success "Using OpenShift CLI (oc)"
    else
        KUBECTL="kubectl"
        print_success "Using kubectl"
    fi
    
    # Check cluster access
    if ! $KUBECTL cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes/OpenShift cluster"
        echo "Please ensure you are logged in to your cluster"
        exit 1
    fi
    print_success "Cluster access confirmed"
}

# Check namespace exists
check_namespace() {
    print_header "Checking Namespace"
    
    if ! $KUBECTL get namespace "$NAMESPACE" &> /dev/null; then
        print_error "Namespace '$NAMESPACE' does not exist"
        echo ""
        echo "Available namespaces with 'devspaces' or 'che' in the name:"
        $KUBECTL get namespaces | grep -E "(devspaces|che)" || echo "  No matching namespaces found"
        echo ""
        echo "Please specify the correct namespace with -n/--namespace option"
        exit 1
    fi
    print_success "Namespace '$NAMESPACE' exists"
}

# Check permissions
check_permissions() {
    if ! $KUBECTL auth can-i create configmaps --namespace="$NAMESPACE" &> /dev/null; then
        print_error "No permission to create ConfigMaps in namespace '$NAMESPACE'"
        echo "Please ensure you have administrative access to the Dev Spaces namespace"
        exit 1
    fi
    print_success "ConfigMap creation permission confirmed"
}

# Delete the editor definition
delete_editor() {
    print_header "Removing No-VSCode Editor Definition"
    
    if $KUBECTL get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" &> /dev/null; then
        $KUBECTL delete configmap "$CONFIGMAP_NAME" -n "$NAMESPACE"
        print_success "ConfigMap '$CONFIGMAP_NAME' deleted"
    else
        print_warning "ConfigMap '$CONFIGMAP_NAME' not found in namespace '$NAMESPACE'"
    fi
    
    echo ""
    print_info "Editor definition removed. Refresh your Dev Spaces dashboard."
}

# Verify deployment
verify_deployment() {
    print_header "Verifying Deployment"
    
    # Check ConfigMap exists
    if ! $KUBECTL get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" &> /dev/null; then
        print_error "ConfigMap '$CONFIGMAP_NAME' not found"
        return 1
    fi
    print_success "ConfigMap exists"
    
    # Check labels
    LABELS=$($KUBECTL get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.metadata.labels}')
    if echo "$LABELS" | grep -q "che.eclipse.org"; then
        print_success "Required labels present"
    else
        print_warning "Labels may be missing"
    fi
    
    # Show ConfigMap details
    echo ""
    echo "ConfigMap Details:"
    $KUBECTL get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" --show-labels
    
    echo ""
    print_success "Deployment verification complete"
    echo ""
    print_info "Editor ID: $EDITOR_ID"
    print_info "API URL: https://<devspaces-url>/dashboard/api/editors/devfile?che-editor=$EDITOR_ID"
}

# Deploy the editor definition
deploy_editor() {
    print_header "Deploying No-VSCode Editor Definition"
    
    # Check if editor definition file exists
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    EDITOR_FILE="$SCRIPT_DIR/$EDITOR_DEFINITION_FILE"
    
    if [ ! -f "$EDITOR_FILE" ]; then
        print_error "Editor definition file not found: $EDITOR_FILE"
        exit 1
    fi
    print_success "Editor definition file found"
    
    # Create or update ConfigMap
    echo ""
    print_info "Creating ConfigMap '$CONFIGMAP_NAME'..."
    
    $KUBECTL create configmap "$CONFIGMAP_NAME" \
        --from-file="$EDITOR_DEFINITION_FILE=$EDITOR_FILE" \
        --namespace="$NAMESPACE" \
        --dry-run=client -o yaml | $KUBECTL apply -f -
    
    print_success "ConfigMap created/updated"
    
    # Add required labels
    print_info "Adding required labels..."
    
    $KUBECTL label configmap "$CONFIGMAP_NAME" \
        app.kubernetes.io/part-of=che.eclipse.org \
        app.kubernetes.io/component=editor-definition \
        --namespace="$NAMESPACE" \
        --overwrite
    
    print_success "Labels applied"
    
    # Verify
    echo ""
    verify_deployment
    
    # Print next steps
    echo ""
    print_header "Deployment Complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Refresh your Dev Spaces dashboard to see the new editor option"
    echo "  2. The editor will appear as 'No VS Code Editor (Red Hat UBI)'"
    echo "  3. Select this editor when creating a new workspace to disable VS Code"
    echo ""
    echo "To use this editor with your devfile, add:"
    echo "  attributes:"
    echo "    che-editor: $EDITOR_ID"
    echo ""
    echo "To make this the default editor, update your CheCluster:"
    echo "  spec:"
    echo "    devEnvironments:"
    echo "      defaultEditor: $EDITOR_ID"
}

# Main execution
check_prerequisites
check_namespace
check_permissions

if [ "$DELETE_MODE" = true ]; then
    delete_editor
elif [ "$VERIFY_MODE" = true ]; then
    verify_deployment
else
    deploy_editor
fi
