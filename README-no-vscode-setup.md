# Creating Dev Spaces Without VS Code in OpenShift

This repository provides a complete solution for creating OpenShift Dev Spaces workspaces that **do not launch VS Code**. This is useful for:

- Running Jupyter Notebooks as the primary interface
- Headless workspaces for automated tasks
- Custom IDE deployments
- Resource-constrained environments

Based on the [Eclipse Che Editor Definitions Documentation](https://eclipse.dev/che/docs/stable/administration-guide/configuring-editors-definitions/).

## Quick Start

### Method 1: Use `editorFree: true` (Simplest)

Add this attribute to your `devfile.yaml`:

```yaml
schemaVersion: 2.3.0
attributes:
  editorFree: true
metadata:
  name: my-workspace
# ... rest of your devfile
```

This tells Dev Spaces to skip the editor entirely. Your workspace will only run the containers you define.

### Method 2: Deploy Custom No-VSCode Editor Definition

For organization-wide control, deploy the custom editor definition:

```bash
# Clone this repository
git clone https://github.com/zconnor-it/testing-dev-spaces.git
cd testing-dev-spaces

# Deploy the no-vscode editor definition
./deploy-no-vscode-editor.sh

# Or specify a custom namespace
./deploy-no-vscode-editor.sh -n eclipse-che
```

## Files in This Repository

| File | Purpose |
|------|---------|
| `devfile.yaml` | Example devfile for Jupyter Notebook workspace without VS Code |
| `no-vscode-editor-definition.yaml` | Custom editor definition using Red Hat UBI |
| `deploy-no-vscode-editor.sh` | Automated deployment script |
| `README-no-vscode-setup.md` | This documentation |

## How It Works

### Understanding Eclipse Che Editor Definitions

Eclipse Che (the upstream project for OpenShift Dev Spaces) uses **editor definitions** to inject IDE components into workspaces. By default, this is VS Code (che-code).

The editor definition is a devfile that specifies:
- **Init containers**: Run during `preStart` to prepare the editor
- **Runtime containers**: Provide the IDE interface with `container-contribution: true`
- **Endpoints**: Expose the IDE on specific ports
- **Commands**: Lifecycle hooks for startup/shutdown

### Our No-VSCode Editor

The `no-vscode-editor-definition.yaml` creates a minimal editor that:

1. Uses Red Hat UBI (Universal Base Image) instead of VS Code
2. Allocates minimal resources (128Mi RAM, 200m CPU)
3. Provides no IDE interface
4. Allows your workspace containers to run without editor overhead

## Deployment Options

### Option A: Deploy Editor Definition (Admin)

Requires cluster admin access to the Dev Spaces namespace:

```bash
# Deploy
./deploy-no-vscode-editor.sh

# Verify
./deploy-no-vscode-editor.sh --verify

# Remove
./deploy-no-vscode-editor.sh --delete
```

### Option B: Manual Deployment

```bash
# Set your namespace
NAMESPACE="openshift-devspaces"

# Create the ConfigMap
kubectl create configmap no-vscode-editor-definition \
  --from-file=no-vscode-editor-definition.yaml \
  -n $NAMESPACE

# Add required labels (CRITICAL - without these, Che won't recognize it)
kubectl label configmap no-vscode-editor-definition \
  app.kubernetes.io/part-of=che.eclipse.org \
  app.kubernetes.io/component=editor-definition \
  -n $NAMESPACE
```

### Option C: Use editorFree in Your Devfile

No admin access needed - just add to your devfile:

```yaml
attributes:
  editorFree: true
```

## Using the No-VSCode Editor

### In Your Devfile

Reference the editor in your devfile:

```yaml
schemaVersion: 2.3.0
attributes:
  che-editor: redhat-custom/no-vscode/1.0.0
metadata:
  name: my-workspace
components:
  - name: my-container
    container:
      image: 'registry.access.redhat.com/ubi9/python-311:latest'
```

### Via URL Parameter

Start a workspace with the editor via URL:

```
https://<devspaces-url>/dashboard/#/<git-repo-url>?che-editor=redhat-custom/no-vscode/1.0.0
```

### As Default for All Workspaces

Update the CheCluster custom resource:

```yaml
apiVersion: org.eclipse.che/v2
kind: CheCluster
metadata:
  name: devspaces
spec:
  devEnvironments:
    defaultEditor: redhat-custom/no-vscode/1.0.0
```

## Example: Jupyter Notebook Workspace

The included `devfile.yaml` demonstrates a Jupyter Notebook workspace without VS Code:

```yaml
schemaVersion: 2.3.0
attributes:
  editorFree: true
metadata:
  name: devspaces-jupyter
  displayName: Devspaces Jupyter Notebook
components:
  - name: runtime
    container:
      image: yourregistry/jupyter-notebook:latest
      command: ["start-notebook.sh"]
      args: ["--ip=0.0.0.0", "--port=8888", "--no-browser"]
      endpoints:
        - name: frontend
          targetPort: 8888
```

Users access Jupyter directly via the exposed endpoint instead of VS Code.

## Verification

### Check Editor Definition Deployment

```bash
# List all editor definitions
kubectl get configmap -n openshift-devspaces \
  -l app.kubernetes.io/component=editor-definition

# View the no-vscode editor
kubectl get configmap no-vscode-editor-definition \
  -n openshift-devspaces -o yaml
```

### Check Via API

```bash
# List all available editors
curl https://<devspaces-url>/dashboard/api/editors

# Get specific editor definition
curl "https://<devspaces-url>/dashboard/api/editors/devfile?che-editor=redhat-custom/no-vscode/1.0.0"
```

### Verify Workspace Started Without VS Code

```bash
# Check running pods in your user namespace
kubectl get pods -n <user-namespace>

# Should NOT see che-code containers
kubectl get pods -n <user-namespace> -o jsonpath='{.items[*].spec.containers[*].name}' | tr ' ' '\n' | grep -v che-code
```

## Troubleshooting

### Editor Not Appearing in Dashboard

1. Check ConfigMap exists with correct labels:
   ```bash
   kubectl get configmap no-vscode-editor-definition \
     -n openshift-devspaces --show-labels
   ```

2. Ensure labels are correct:
   - `app.kubernetes.io/part-of=che.eclipse.org`
   - `app.kubernetes.io/component=editor-definition`

3. Refresh the Dev Spaces dashboard (clear browser cache)

### Workspace Fails to Start

1. Check the DevWorkspace status:
   ```bash
   kubectl get devworkspace -n <user-namespace>
   kubectl describe devworkspace <workspace-name> -n <user-namespace>
   ```

2. Verify the container image is accessible:
   ```bash
   kubectl run test-ubi \
     --image=registry.access.redhat.com/ubi9/ubi-minimal:latest \
     --rm -it --restart=Never -- echo "Access OK"
   ```

### Permission Denied Errors

Ensure you have admin access to the Dev Spaces namespace:
```bash
kubectl auth can-i create configmaps -n openshift-devspaces
```

## Red Hat UBI Images

The solution uses Red Hat Universal Base Image for enterprise compliance:

| Image | Size | Use Case |
|-------|------|----------|
| `ubi9/ubi-minimal:latest` | ~37MB | Smallest footprint (default) |
| `ubi9/ubi:latest` | ~211MB | Full tools and utilities |
| `ubi9/ubi-init:latest` | ~230MB | SystemD support |

## References

- [Eclipse Che - Configuring Editors Definitions](https://eclipse.dev/che/docs/stable/administration-guide/configuring-editors-definitions/)
- [Devfile Schema Documentation](https://devfile.io/)
- [OpenShift Dev Spaces Documentation](https://access.redhat.com/documentation/en-us/red_hat_openshift_dev_spaces/)
- [Red Hat UBI Documentation](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/building_running_and_managing_containers/using_red_hat_universal_base_images_standard_minimal_and_runtimes)

## License

This project is provided as-is for educational and demonstration purposes.
