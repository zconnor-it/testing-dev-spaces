# Jupyter Notebook in OpenShift Dev Spaces (Without VS Code)

This repository provides a solution for creating OpenShift Dev Spaces workspaces that run **Jupyter Notebook instead of VS Code**.

Based on the [Eclipse Che Editor Definitions Documentation](https://eclipse.dev/che/docs/stable/administration-guide/configuring-editors-definitions/).

## Overview

OpenShift Dev Spaces uses VS Code as the default editor. This solution deploys a **custom editor definition** that prevents VS Code from loading, allowing you to use Jupyter Notebook as the primary interface.

## Requirements

- **Cluster administrator access** to the `openshift-devspaces` namespace (for initial setup)
- OpenShift CLI (`oc`) or `kubectl`

## Files in This Repository

| File | Purpose |
|------|---------|
| `devfile.yaml` | Defines Jupyter container with auto-install and token authentication |
| `no-vscode-editor-definition.yaml` | Custom editor definition that prevents VS Code |
| `deploy-no-vscode-editor.sh` | Deployment script for administrators |
| `README-no-vscode-setup.md` | This documentation |

## Initial Setup (Administrator)

### Step 1: Clone the Repository

```bash
git clone https://github.com/zconnor-it/testing-dev-spaces.git
cd testing-dev-spaces
```

### Step 2: Log into OpenShift

```bash
oc login <your-openshift-api-url> --token=<your-token>
```

### Step 3: Deploy the Editor Definition

```bash
./deploy-no-vscode-editor.sh
```

Or specify a custom namespace:
```bash
./deploy-no-vscode-editor.sh -n eclipse-che
```

### Step 4: Verify Deployment

```bash
./deploy-no-vscode-editor.sh --verify
```

## Creating a Jupyter Workspace (Users)

After the administrator deploys the editor definition:

1. Go to the **Dev Spaces dashboard**
2. Click **"Create Workspace"**
3. Select **"No VS Code (Use Devfile Container)"** as the editor
4. Enter the Git repo URL: `https://github.com/zconnor-it/testing-dev-spaces`
5. Click **"Create & Open"**

The workspace will:
- Install JupyterLab automatically
- Generate a unique authentication token
- Start JupyterLab on port 8888

## Accessing Jupyter Notebook

### Finding Your Authentication Token

Each workspace session generates a unique token for security. To find your token:

#### Option 1: From Dev Spaces Dashboard
1. Click on your running workspace
2. Go to the **"Logs"** tab
3. Select the **"jupyter"** container
4. Find the token block:
   ```
   ==============================================
   JUPYTER AUTHENTICATION TOKEN
   ==============================================
   Your Jupyter token for this session:
   
     <your-64-character-token-here>
   ==============================================
   ```

#### Option 2: Via Command Line
```bash
# Get pod name
oc get pods -n <your-namespace>

# View token from logs
oc logs <pod-name> -c jupyter -n <your-namespace> | grep -A 3 "Your Jupyter token"

# Or read from file
oc exec <pod-name> -c jupyter -n <your-namespace> -- cat /tmp/jupyter-token.txt
```

### Accessing the Jupyter URL

1. Get the workspace URL:
   ```bash
   oc get devworkspace -n <your-namespace> -o jsonpath='{.items[0].status.mainUrl}'
   ```

2. Open the URL in your browser

3. When prompted, enter your token

## Security

| Protection | Description |
|------------|-------------|
| **Token Authentication** | Random 64-character token required for access |
| **Per-Session Tokens** | New token generated on each workspace restart |
| **HTTPS** | All traffic encrypted via TLS |
| **Workspace Isolation** | Each user has their own workspace namespace |

## Script Options

```bash
./deploy-no-vscode-editor.sh              # Deploy to openshift-devspaces
./deploy-no-vscode-editor.sh -n NAMESPACE # Deploy to custom namespace
./deploy-no-vscode-editor.sh --verify     # Verify deployment
./deploy-no-vscode-editor.sh --delete     # Remove editor definition
./deploy-no-vscode-editor.sh --help       # Show help
```

## Customization

### Change Memory/CPU Limits

Edit `devfile.yaml`:
```yaml
memoryLimit: 8Gi
memoryRequest: 2Gi
```

### Use a Different Jupyter Image

Replace the image in `devfile.yaml`:
```yaml
image: your-registry/your-jupyter-image:tag
```

### Disable Token Authentication

Edit the startup command in `devfile.yaml` to use empty token:
```bash
jupyter lab --ServerApp.token='' --ServerApp.password=''
```

## Troubleshooting

### Workspace Won't Start

Check pod status:
```bash
oc get pods -n <your-namespace>
oc describe pod <pod-name> -n <your-namespace>
```

### Container CrashLoopBackOff

Check container logs:
```bash
oc logs <pod-name> -c jupyter -n <your-namespace>
```

### Storage Error (0-size PVC)

Ensure the CheCluster has storage configured:
```bash
oc get checluster -n openshift-devspaces -o yaml | grep -A 10 storage
```

If missing, patch it:
```bash
oc patch checluster devspaces -n openshift-devspaces --type=merge -p '
{
  "spec": {
    "devEnvironments": {
      "storage": {
        "pvcStrategy": "per-workspace",
        "perWorkspaceStrategyPvcConfig": {
          "claimSize": "5Gi"
        }
      }
    }
  }
}'
```

### Editor Not Appearing in Dashboard

Verify ConfigMap exists with correct labels:
```bash
oc get configmap -n openshift-devspaces -l app.kubernetes.io/component=editor-definition
```

## Removal

To remove the custom editor definition:

```bash
./deploy-no-vscode-editor.sh --delete
```

## References

- [Eclipse Che - Configuring Editors Definitions](https://eclipse.dev/che/docs/stable/administration-guide/configuring-editors-definitions/)
- [Red Hat OpenShift Dev Spaces Documentation](https://docs.redhat.com/documentation/en-us/red_hat_openshift_dev_spaces/)
- [Devfile Schema Documentation](https://devfile.io/)
- [JupyterLab Documentation](https://jupyterlab.readthedocs.io/)
