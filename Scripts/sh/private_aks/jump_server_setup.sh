# Run on the jump host (Ubuntu):
sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update && sudo apt-get install -y kubectl
sudo snap install kubelogin

# Get kubeconfig and convert to MSI auth (run on jump host)
az aks get-credentials -g "$RG" -n "$AKS" --overwrite-existing || true
chmod 600 ~/.kube/config || true
kubelogin convert-kubeconfig -l msi --kubeconfig ~/.kube/config || true
sed -i 's|command: .*kubelogin|command: /snap/bin/kubelogin|' ~/.kube/config || true
awk '/exec:/{in=1} in&&/apiVersion:/{print;print " env:\n - name: PATH\n   value: /usr/bin:/usr/local/bin:/bin:/snap/bin";next} {print}' \
  ~/.kube/config > ~/.kube/config.new && mv ~/.kube/config.new ~/.kube/config

# Grant roles to the jump VM MSI (objectId below is example)
az role assignment create --assignee "$JUMP_VM_MI_OBJID" --role "Azure Kubernetes Service Cluster User Role" --scope "$AKS_ID" || true
az role assignment create --assignee "$JUMP_VM_MI_OBJID" --role "Azure Kubernetes Service RBAC Reader" --scope "$AKS_ID" || true
