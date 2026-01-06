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

### Step 3: Create the ConfigMap

Create a ConfigMap from the editor definition file:

```bash
oc create configmap no-vscode-editor-definition \
  --from-file=no-vscode-editor-definition.yaml \
  -n openshift-devspaces
```

If using a different namespace (e.g., `eclipse-che`):
```bash
oc create configmap no-vscode-editor-definition \
  --from-file=no-vscode-editor-definition.yaml \
  -n eclipse-che
```

### Step 4: Add Required Labels

The ConfigMap **must** have these labels for Dev Spaces to recognize it as an editor definition:

```bash
oc label configmap no-vscode-editor-definition \
  app.kubernetes.io/part-of=che.eclipse.org \
  app.kubernetes.io/component=editor-definition \
  -n openshift-devspaces
```

### Step 5: Verify Deployment

Check that the ConfigMap exists with correct labels:

```bash
oc get configmap no-vscode-editor-definition -n openshift-devspaces --show-labels
```

Expected output should show both labels:
```
NAME                          DATA   AGE   LABELS
no-vscode-editor-definition   1      1m    app.kubernetes.io/component=editor-definition,app.kubernetes.io/part-of=che.eclipse.org
```

### Step 6: Refresh Dev Spaces Dashboard

Refresh your browser on the Dev Spaces dashboard. The new editor option **"No VS Code (Use Devfile Container)"** should now appear in the editor dropdown when creating a workspace.

## Updating the Editor Definition

If you need to update the editor definition:

```bash
# Delete the existing ConfigMap
oc delete configmap no-vscode-editor-definition -n openshift-devspaces

# Recreate with updated file
oc create configmap no-vscode-editor-definition \
  --from-file=no-vscode-editor-definition.yaml \
  -n openshift-devspaces

# Re-add labels
oc label configmap no-vscode-editor-definition \
  app.kubernetes.io/part-of=che.eclipse.org \
  app.kubernetes.io/component=editor-definition \
  -n openshift-devspaces
```

Or use `--dry-run` to update in place:

```bash
oc create configmap no-vscode-editor-definition \
  --from-file=no-vscode-editor-definition.yaml \
  -n openshift-devspaces \
  --dry-run=client -o yaml | oc apply -f -

oc label configmap no-vscode-editor-definition \
  app.kubernetes.io/part-of=che.eclipse.org \
  app.kubernetes.io/component=editor-definition \
  -n openshift-devspaces \
  --overwrite
```

## Removing the Editor Definition

To remove the custom editor:

```bash
oc delete configmap no-vscode-editor-definition -n openshift-devspaces
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

## Using Your Own Git Repository

You can use your own Git repository with a custom devfile instead of this repository. This allows you to:
- Use your own Jupyter notebooks and data
- Customize the container configuration
- Pre-install additional Python packages

### Step 1: Create a Devfile in Your Repository

Create a `devfile.yaml` file in the root of your Git repository:

```yaml
# devfile.yaml
schemaVersion: 2.1.0

metadata:
  name: my-jupyter-workspace
  displayName: My Jupyter Workspace
  description: Custom Jupyter Notebook workspace

components:
  # Storage volume (required to avoid 0-size PVC error)
  - name: projects
    volume:
      size: 5Gi

  - name: jupyter
    container:
      image: registry.access.redhat.com/ubi9/python-311:latest
      memoryLimit: 4Gi
      memoryRequest: 1Gi
      mountSources: true
      sourceMapping: /projects
      volumeMounts:
        - name: projects
          path: /projects
      args:
        - /bin/bash
        - -c
        - |
          echo "Installing JupyterLab..."
          pip install jupyterlab
          
          # Add your custom packages here
          # pip install pandas numpy matplotlib scikit-learn
          
          # Generate authentication token
          JUPYTER_TOKEN=$(python -c "import secrets; print(secrets.token_hex(32))")
          
          echo ""
          echo "=============================================="
          echo "JUPYTER AUTHENTICATION TOKEN"
          echo "=============================================="
          echo "Your Jupyter token for this session:"
          echo ""
          echo "  $JUPYTER_TOKEN"
          echo "=============================================="
          echo ""
          
          echo "$JUPYTER_TOKEN" > /tmp/jupyter-token.txt
          
          echo "Starting JupyterLab on port 8888..."
          jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --ServerApp.token="$JUPYTER_TOKEN" --notebook-dir=/projects
      endpoints:
        - name: jupyter
          targetPort: 8888
          exposure: public
          protocol: https
          attributes:
            type: main
```

### Step 2: Commit and Push

```bash
git add devfile.yaml
git commit -m "Add Jupyter devfile"
git push
```

### Step 3: Create Workspace with Your Repo

1. Go to the **Dev Spaces dashboard**
2. Click **"Create Workspace"**
3. Select **"No VS Code (Use Devfile Container)"** as the editor
4. Enter **your Git repository URL**
5. Click **"Create & Open"**

### Customizing Your Devfile

#### Pre-install Python Packages

Add packages to the startup script:

```yaml
args:
  - /bin/bash
  - -c
  - |
    pip install jupyterlab pandas numpy matplotlib scikit-learn tensorflow
    # ... rest of startup script
```

#### Use a Custom Container Image

If you have a pre-built Jupyter image:

```yaml
container:
  image: your-registry.com/your-jupyter-image:tag
  # Remove the pip install commands if Jupyter is pre-installed
  args:
    - /bin/bash
    - -c
    - |
      JUPYTER_TOKEN=$(python -c "import secrets; print(secrets.token_hex(32))")
      echo "Token: $JUPYTER_TOKEN"
      echo "$JUPYTER_TOKEN" > /tmp/jupyter-token.txt
      jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --ServerApp.token="$JUPYTER_TOKEN" --notebook-dir=/projects
```

#### Increase Resources

```yaml
container:
  memoryLimit: 16Gi
  memoryRequest: 4Gi
```

#### Change Storage Size

```yaml
components:
  - name: projects
    volume:
      size: 20Gi
```

### Important Notes for Custom Devfiles

1. **Volume is required**: Always include the `projects` volume with a size to avoid storage errors
2. **Repository must be accessible**: The repo must be public, or Dev Spaces must have OAuth configured for private repos
3. **Container must stay running**: The container needs a long-running process (like `jupyter lab`)
4. **Endpoint must be defined**: Include the `endpoints` section so you can access Jupyter

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

If labels are missing, add them:
```bash
oc label configmap no-vscode-editor-definition \
  app.kubernetes.io/part-of=che.eclipse.org \
  app.kubernetes.io/component=editor-definition \
  -n openshift-devspaces
```

### Devfile Not Being Read from Private Repo

If using a private Git repository, ensure OAuth is configured:
```bash
# Check if GitHub OAuth is configured
oc get secret -n openshift-devspaces -l app.kubernetes.io/component=oauth-scm-configuration
```

## References

- [Eclipse Che - Configuring Editors Definitions](https://eclipse.dev/che/docs/stable/administration-guide/configuring-editors-definitions/)
- [Red Hat OpenShift Dev Spaces Documentation](https://docs.redhat.com/documentation/en-us/red_hat_openshift_dev_spaces/)
- [Devfile Schema Documentation](https://devfile.io/)
- [JupyterLab Documentation](https://jupyterlab.readthedocs.io/)
