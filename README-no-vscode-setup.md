# Preventing VS Code Startup in OpenShift Dev Spaces with Red Hat UBI

This directory contains files to prevent VS Code from starting in OpenShift Dev Spaces environments by deploying a custom editor definition that replaces VS Code with a minimal Red Hat Universal Base Image (UBI) container.

## Files

- `no-vscode-editor-definition.yaml` - Custom Red Hat UBI-based editor definition that prevents VS Code startup
- `deploy-no-vscode-editor.sh` - Automated deployment script for Red Hat UBI solution
- `README-no-vscode-setup.md` - This documentation file

## How It Works

The solution uses Eclipse Che's custom editor definition feature with Red Hat containers to:

1. **Replace VS Code**: Creates a custom editor definition that overrides the default VS Code editor
2. **Red Hat UBI Container**: Uses Red Hat Universal Base Image 9 (UBI9) minimal container for compliance
3. **Resource Minimal**: Allocates minimal resources (64Mi RAM, 100m CPU) 
4. **No IDE Interface**: Provides no actual IDE interface, just status messages
5. **Clear Messaging**: Displays messages explaining that VS Code has been disabled
6. **Red Hat Compliance**: Uses only Red Hat certified container images

## Quick Start

1. **Deploy the editor definition**:
   ```bash
   ./deploy-no-vscode-editor.sh
   ```

2. **Verify deployment**:
   ```bash
   kubectl get configmap no-vscode-editor-definition-ubi -n openshift-devspaces
   ```

3. **Check available editors via API**:
   ```bash
   curl https://<your-devspaces-url>/dashboard/api/editors
   ```

4. **Verify Red Hat UBI container**:
   ```bash
   kubectl get configmap no-vscode-editor-definition-ubi -n openshift-devspaces -o yaml | grep "ubi9/ubi-minimal"
   ```

## Manual Deployment Steps

If you prefer to deploy manually instead of using the script:

1. **Create ConfigMap**:
   ```bash
   kubectl create configmap no-vscode-editor-definition-ubi \
     --from-file=no-vscode-editor-definition.yaml \
     -n openshift-devspaces
   ```

2. **Add required labels**:
   ```bash
   kubectl label configmap no-vscode-editor-definition-ubi \
     app.kubernetes.io/part-of=che.eclipse.org \
     app.kubernetes.io/component=editor-definition \
     -n openshift-devspaces
   ```

## Making It Default (Optional)

To make this Red Hat UBI-based editor the default for all new workspaces, you can:

### Option 1: Update CheCluster Custom Resource
```yaml
apiVersion: org.eclipse.che/v2
kind: CheCluster
metadata:
  name: devspaces
spec:
  devEnvironments:
    defaultEditor: redhat-custom/no-vscode/1.0.0
```

### Option 2: Configure in Dashboard
1. Access Dev Spaces dashboard as admin
2. Go to administration settings  
3. Set default editor to `redhat-custom/no-vscode/1.0.0`

## Verification

After deployment, you can verify the Red Hat UBI-based editor definition is available:

1. **Via API**: `https://<devspaces-url>/dashboard/api/editors/devfile?che-editor=redhat-custom/no-vscode/1.0.0`
2. **Via Dashboard**: Check the editor selection dropdown in workspace creation (look for "No VS Code Editor (Red Hat UBI)")
3. **Via kubectl**: `kubectl get configmap no-vscode-editor-definition-ubi -n openshift-devspaces -o yaml`
4. **Container Image**: Verify UBI image: `registry.access.redhat.com/ubi9/ubi-minimal:latest`

## What Users Will See

When users try to create a workspace with this Red Hat UBI editor:

- The workspace will start successfully using Red Hat UBI containers
- Instead of VS Code, they'll see a minimal Red Hat container
- Console output will show Red Hat UBI information and VS Code disabled messages
- No IDE interface will be available
- Resource usage will be minimal (64Mi RAM, 100m CPU)
- Full Red Hat container compliance and support

## Customization

You can modify the Red Hat UBI-based editor definition to:

- **Change the UBI version**: Update to different Red Hat UBI images (ubi8, ubi9, different variants)
- **Modify resource limits**: Adjust `memoryLimit`, `cpuLimit`, etc.
- **Update messaging**: Change the command outputs and environment variables
- **Add Red Hat tooling**: Include additional Red Hat tools or monitoring
- **Different UBI variants**: Use `registry.access.redhat.com/ubi9/ubi:latest` for full UBI instead of minimal

## Available Red Hat UBI Images

- `registry.access.redhat.com/ubi9/ubi-minimal:latest` (currently used - smallest)
- `registry.access.redhat.com/ubi9/ubi:latest` (full UBI with more tools)
- `registry.access.redhat.com/ubi8/ubi-minimal:latest` (UBI 8 minimal)
- `registry.access.redhat.com/ubi8/ubi:latest` (UBI 8 full)

## Removal

To remove the Red Hat UBI no-vscode editor definition:

```bash
kubectl delete configmap no-vscode-editor-definition-ubi -n openshift-devspaces
```

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure you have admin access to the OpenShift Dev Spaces namespace
2. **Namespace Not Found**: Verify the correct namespace name (might be `eclipse-che` instead of `openshift-devspaces`)
3. **Editor Not Appearing**: Check that the ConfigMap has the correct labels
4. **Workspace Won't Start**: Verify the container image is accessible from your cluster

### Checking Logs

```bash
# Check if Red Hat UBI ConfigMap exists and has correct labels
kubectl get configmap no-vscode-editor-definition-ubi -n openshift-devspaces --show-labels

# Check the Red Hat UBI editor definition content
kubectl get configmap no-vscode-editor-definition-ubi -n openshift-devspaces -o yaml

# Verify Red Hat UBI container image
kubectl get configmap no-vscode-editor-definition-ubi -n openshift-devspaces -o yaml | grep "ubi9/ubi-minimal"

# Check available editors via API (replace with your actual URL)
curl https://your-devspaces-url/dashboard/api/editors

# Check if Red Hat registry is accessible from cluster
kubectl run test-ubi --image=registry.access.redhat.com/ubi9/ubi-minimal:latest --rm -it --restart=Never -- echo "UBI access test"
```

## Red Hat UBI Benefits

Using Red Hat Universal Base Image provides:

- **Enterprise Support**: Full Red Hat support and updates
- **Security**: Regular security updates and CVE patching
- **Compliance**: Meets enterprise security and compliance requirements
- **Minimal Attack Surface**: UBI Minimal reduces container footprint
- **Container Optimization**: Optimized for container environments
- **Registry Access**: Available from Red Hat's public registry without authentication

## References

- [Eclipse Che Editor Definitions Documentation](https://eclipse.dev/che/docs/stable/administration-guide/configuring-editors-definitions/)
- [Devfile Schema Documentation](https://devfile.io/)
- [OpenShift Dev Spaces Documentation](https://access.redhat.com/documentation/en-us/red_hat_openshift_dev_spaces/)
- [Red Hat Universal Base Image Documentation](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/building_running_and_managing_containers/using_red_hat_universal_base_images_standard_minimal_and_runtimes)
- [Red Hat Container Catalog - UBI](https://catalog.redhat.com/software/containers/ubi9/ubi-minimal)
