#!/bin/bash
#
# Script to deploy the Red Hat UBI-based no-vscode editor definition that prevents VS Code from starting
# in OpenShift Dev Spaces (Eclipse Che) using Red Hat Universal Base Image containers
#

set -e

# Configuration
NAMESPACE="openshift-devspaces"  # Default OpenShift Dev Spaces namespace
EDITOR_DEFINITION_FILE="no-vscode-editor-definition.yaml"
CONFIGMAP_NAME="no-vscode-editor-definition-ubi"

echo "======================================================="
echo "Deploying Red Hat UBI No-VSCode Editor Definition"
echo "======================================================="
echo "Using Red Hat Universal Base Image (UBI9) containers"

# Check if the editor definition file exists
if [ ! -f "$EDITOR_DEFINITION_FILE" ]; then
    echo "ERROR: $EDITOR_DEFINITION_FILE not found in current directory"
    exit 1
fi

# Check if we have kubectl access
if ! kubectl auth can-i create configmaps --namespace="$NAMESPACE" 2>/dev/null; then
    echo "ERROR: No permission to create ConfigMaps in namespace '$NAMESPACE'"
    echo "Please ensure you have administrative access to the OpenShift Dev Spaces namespace"
    exit 1
fi

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "WARNING: Namespace '$NAMESPACE' does not exist"
    echo "Available namespaces with 'devspaces' or 'che' in the name:"
    kubectl get namespaces | grep -E "(devspaces|che)" || echo "No matching namespaces found"
    echo ""
    echo "Please update the NAMESPACE variable in this script or create the namespace"
    exit 1
fi

echo "Target namespace: $NAMESPACE"
echo "Editor definition file: $EDITOR_DEFINITION_FILE"
echo ""

# Create or update the ConfigMap
echo "Creating ConfigMap '$CONFIGMAP_NAME'..."
kubectl create configmap "$CONFIGMAP_NAME" \
    --from-file="$EDITOR_DEFINITION_FILE" \
    --namespace="$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

# Add required labels to the ConfigMap
echo "Adding required labels to ConfigMap..."
kubectl label configmap "$CONFIGMAP_NAME" \
    app.kubernetes.io/part-of=che.eclipse.org \
    app.kubernetes.io/component=editor-definition \
    --namespace="$NAMESPACE" \
    --overwrite

# Verify the ConfigMap was created
echo ""
echo "Verifying deployment..."
kubectl get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o yaml | head -20

echo ""
echo "======================================================="
echo "Red Hat UBI Deployment Complete!"
echo "======================================================="
echo ""
echo "The Red Hat UBI-based no-vscode editor definition has been deployed successfully."
echo "This solution uses Red Hat Universal Base Image (UBI9) containers for compliance."
echo ""
echo "Next steps:"
echo "1. Refresh your Dev Spaces dashboard to see the new Red Hat UBI editor option"
echo "2. The editor will be available at: https://<devspaces-url>/dashboard/api/editors"
echo "3. To make this the default editor for all workspaces, you'll need to:"
echo "   - Update the CheCluster custom resource, or"
echo "   - Configure it as the default in the dashboard settings"
echo ""
echo "To access the Red Hat UBI editor definition API:"
echo "   https://<devspaces-url>/dashboard/api/editors/devfile?che-editor=redhat-custom/no-vscode/1.0.0"
echo ""
echo "Container Details:"
echo "   Image: registry.access.redhat.com/ubi9/ubi-minimal:latest"
echo "   Type: Red Hat Universal Base Image 9 (Minimal)"
echo "   Purpose: VS Code prevention with Red Hat compliance"
echo ""
echo "To remove this editor definition:"
echo "   kubectl delete configmap $CONFIGMAP_NAME -n $NAMESPACE"
echo ""

# Show how to verify the Red Hat UBI editor is available
echo "To verify the Red Hat UBI editor is available:"
echo "1. Via kubectl: kubectl get configmap $CONFIGMAP_NAME -n $NAMESPACE"
echo "2. Via API: https://<devspaces-url>/dashboard/api/editors"
echo "3. Look for 'redhat-custom/no-vscode/1.0.0' in the API response"
echo "4. Verify container image: registry.access.redhat.com/ubi9/ubi-minimal:latest"
echo ""
