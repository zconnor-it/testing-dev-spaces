# Disabling VS Code in OpenShift Dev Spaces

This repository provides a solution for creating OpenShift Dev Spaces workspaces that **do not launch VS Code** by deploying a custom editor definition.

Based on the [Eclipse Che Editor Definitions Documentation](https://eclipse.dev/che/docs/stable/administration-guide/configuring-editors-definitions/).

## Overview

OpenShift Dev Spaces uses VS Code as the default editor. To disable it, you must deploy a **custom editor definition** as a ConfigMap in the Dev Spaces namespace. This requires **cluster administrator access**.

## Files in This Repository

| File | Purpose |
|------|---------|
| `devfile.yaml` | Example devfile for testing workspaces |
| `no-vscode-editor-definition.yaml` | Custom editor definition using Red Hat UBI (no VS Code) |
| `deploy-no-vscode-editor.sh` | Automated deployment script for administrators |
| `README-no-vscode-setup.md` | This documentation |

## Requirements

- **Cluster administrator access** to the `openshift-devspaces` namespace
- OpenShift CLI (`oc`) or `kubectl`

## Deployment Steps

### Step 1: Log into OpenShift

```bash
oc login <your-openshift-api-url> --token=<your-token>
```

### Step 2: Deploy the Editor Definition

```bash
# Clone this repository
git clone https://github.com/zconnor-it/testing-dev-spaces.git
cd testing-dev-spaces

# Run the deployment script
./deploy-no-vscode-editor.sh

# Or specify a custom namespace
./deploy-no-vscode-editor.sh -n eclipse-che
```

### Manual Deployment (Alternative)

```bash
NAMESPACE="openshift-devspaces"

# Create the ConfigMap
oc create configmap no-vscode-editor-definition \
  --from-file=no-vscode-editor-definition.yaml \
  -n $NAMESPACE

# Add required labels (CRITICAL)
oc label configmap no-vscode-editor-definition \
  app.kubernetes.io/part-of=che.eclipse.org \
  app.kubernetes.io/component=editor-definition \
  -n $NAMESPACE
```

### Step 3: Verify Deployment

```bash
./deploy-no-vscode-editor.sh --verify
```

Or manually:
```bash
oc get configmap no-vscode-editor-definition -n openshift-devspaces --show-labels
```

## Using the No-VSCode Editor

After deployment, the editor will be available in the Dev Spaces dashboard.

### Option A: Select in Dashboard

1. Go to Dev Spaces dashboard
2. Create a new workspace
3. Select **"No VS Code Editor (Red Hat UBI)"** from the editor dropdown
4. Enter your Git repository URL
5. Click Create & Open

### Option B: Use URL Parameter

```
https://<devspaces-url>/#<git-repo-url>?che-editor=redhat-custom/no-vscode/1.0.0
```

### Option C: Reference in Devfile

Add to your project's `devfile.yaml`:

```yaml
schemaVersion: 2.1.0
attributes:
  che-editor: redhat-custom/no-vscode/1.0.0
metadata:
  name: my-workspace
components:
  - name: runtime
    container:
      image: your-image:tag
```

### Option D: Set as Cluster Default

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

## Script Options

```bash
./deploy-no-vscode-editor.sh              # Deploy to openshift-devspaces
./deploy-no-vscode-editor.sh -n NAMESPACE # Deploy to custom namespace
./deploy-no-vscode-editor.sh --verify     # Verify deployment
./deploy-no-vscode-editor.sh --delete     # Remove editor definition
./deploy-no-vscode-editor.sh --help       # Show help
```

## Verification

### Check ConfigMap

```bash
oc get configmap no-vscode-editor-definition \
  -n openshift-devspaces --show-labels
```

### Check API

```bash
curl "https://<devspaces-url>/dashboard/api/editors"
```

### Check Specific Editor

```bash
curl "https://<devspaces-url>/dashboard/api/editors/devfile?che-editor=redhat-custom/no-vscode/1.0.0"
```

## Troubleshooting

### Editor Not Appearing in Dashboard

1. Verify ConfigMap exists with correct labels:
   ```bash
   oc get configmap no-vscode-editor-definition \
     -n openshift-devspaces --show-labels
   ```

2. Required labels:
   - `app.kubernetes.io/part-of=che.eclipse.org`
   - `app.kubernetes.io/component=editor-definition`

3. Clear browser cache and refresh the dashboard

### Permission Denied

You need cluster admin access to the Dev Spaces namespace:
```bash
oc auth can-i create configmaps -n openshift-devspaces
```

### Workspace Fails to Start

Check DevWorkspace status:
```bash
oc get devworkspace -n <user-namespace>
oc describe devworkspace <workspace-name> -n <user-namespace>
```

## Removal

```bash
./deploy-no-vscode-editor.sh --delete
```

Or manually:
```bash
oc delete configmap no-vscode-editor-definition -n openshift-devspaces
```

## References

- [Eclipse Che - Configuring Editors Definitions](https://eclipse.dev/che/docs/stable/administration-guide/configuring-editors-definitions/)
- [Red Hat OpenShift Dev Spaces Documentation](https://docs.redhat.com/documentation/en-us/red_hat_openshift_dev_spaces/)
- [Devfile Schema Documentation](https://devfile.io/)
