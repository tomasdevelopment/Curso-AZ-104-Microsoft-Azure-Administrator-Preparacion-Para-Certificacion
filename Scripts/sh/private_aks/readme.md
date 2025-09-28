AKS Private Networking Guide (UAMI + RBAC)

We’re going to stand up a private AKS cluster on your own VNet using Azure CNI Overlay, wire it to Azure Monitor, and set up access from a jump server via kubelogin (MSI).
 You can choose between:

    • Option A — Single UAMI (simple): one User-Assigned Managed Identity used by both control plane and kubelet. Easiest to operate; fewer identities to track (Sh deploy template included) https://github.com/tomasdevelopment/Curso-AZ-104-Microsoft-Azure-Administrator-Preparacion-Para-Certificacion/tree/main/Scripts/sh/private_aks.
    • Option B — Split UAMIs (tighter IAM): one UAMI for control plane, another UAMI for kubelet. Lets you scope networking rights to kubelet only and keep control-plane IAM cleaner. (template not included) 
We’ll keep role assignments least-privilege and clearly separated into:
    • Network (e.g., subnet/LB/PIP changes),
    • Control Plane / ARM (e.g., get credentials),
    • In-cluster / Azure RBAC (what kubectl can do).
Why one vs two identities?
    • One UAMI: fastest path, fewer moving parts, great for small teams or labs.
    • Two UAMIs: production-friendly when you want to limit broad network permissions — grant Network Contributor to the kubelet UAMI (on the node subnet/MC RG) while keeping the control-plane UAMI with only what it truly needs.
What you’ll get at the end
    • Private AKS cluster attached to your VNet (Azure CNI Overlay)
    • Azure Monitor collection enabled
    • Jump host login flow using kubelogin in MSI mode
    • Ready-to-run az snippets to assign only the roles required for:
    • Networking (subnet, MC resource group, optional PIP)
    • Control plane access (get credentials)
    • In-cluster permissions (Reader/Writer/Admin/Cluster Admin)
Tip: Start with Option A (single UAMI). If later you need stricter separation, switch to Option B by creating a second UAMI and moving the kubelet/network roles over — no need to redesign everything.
0) Prerequisites
Azure bits
    • Azure CLI ≥ 2.58 (or recent). Check with: az version
    • Logged in and correct subscription and with the sytem identity to use the jump server:
az login --identity
az account show - query id -o tsv
az account set - subscription "<sub-id>"
    • Install kubectl & kubelogin on the jump host or have vpn or express route pre installed:
    • az aks install-cli # installs kubectl via Azure CLI (or use apt instructions below)
    • sudo snap install kubelogin
VNet & CIDR planning (Overlay-friendly sizing)
    • VNet address space: e.g., 10.224.0.0/16 (room for future subnets).
    • Node subnet: start with /24 (e.g., 10.224.1.0/24). Scale to /23 or /22 if you’ll run many nodes.
    • Pod CIDR (overlay): e.g., 10.240.0.0/16 (does not consume VNet IPs; keep it non‑overlapping with your corp network).
    • Service CIDR (if you customize): e.g., 10.2.0.0/16 (non‑overlapping with VNet & Pod CIDR). Not required for basic flow here.
Why Overlay? Pod IPs are decoupled from VNet space, simplifying IP planning in enterprises while retaining routability inside the cluster.
Quotas / SKUs
    • If you hit vCPU quota, use a smaller size (e.g., Standard_B2s) or request quota for the region.
1) Variables
SUB="123"
RG="posada_pintoresca_mx"
AKS="akstest"
REGION="mexicocentral"
# BYO VNet
VNET_RG="$RG"
VNET_NAME="yourvnet"
SUBNET_NAME="default"
VNET_ID="/subscriptions/$SUB/resourceGroups/$VNET_RG/providers/Microsoft.Network/virtualNetworks/$VNET_NAME"
SUBNET_ID="${VNET_ID}/subnets/${SUBNET_NAME}"
# Log Analytics workspace (example: DefaultWorkspace in East US)
WORKSPACE_ID="/subscriptions/123/resourceGroups/DefaultResourceGroup-EUS/providers/Microsoft.OperationalInsights/workspaces/DefaultWorkspace-123-EUS"
# Node size
SIZE="Standard_D2ps_v6"   # change if quota issues (e.g., Standard_B2s)
2) Create ONE UAMI and Network role
az identity create -g "$RG" -n "aks_test_02-uami" -l "$REGION"
UAI_ID=$(az identity show -g "$RG" -n "aks_test_02-uami" --query id -o tsv)
UAI_PID=$(az identity show -g "$RG" -n "aks_test_02-uami" --query principalId -o tsv)
Required for BYO VNet: kubelet (UAMI) needs Network Contributor on the NODE SUBNET
az role assignment create \
 - assignee-object-id "$UAI_PID" - assignee-principal-type ServicePrincipal \
 - role "Network Contributor" - scope "$SUBNET_ID"
If pulling from ACR, also grant AcrPull on your ACR to the same UAMI.
3) Create the AKS cluster (Azure CNI Overlay + Monitoring)
Leave — network-policy unspecified (defaults to none). Use — generate-ssh-keys to auto-create SSH keys.
3A) Baseline K8s only login and authentication
az aks create -g "$RG" -n "$AKS" -l "$REGION" \
 - enable-managed-identity \
 - assign-identity "$UAI_ID" \
 - assign-kubelet-identity "$UAI_ID" \
 - network-plugin azure \
 - network-plugin-mode overlay \
 - pod-cidr 10.240.0.0/16 \
 - vnet-subnet-id "$SUBNET_ID" \
 - vm-set-type VirtualMachines \
 - nodepool-name systempool \
 - node-vm-size "$SIZE" \
 - node-count 1 \
 - enable-addons monitoring \
 - workspace-resource-id "$WORKSPACE_ID" \
 - auto-upgrade-channel none \
 - node-os-upgrade-channel NodeImage \
 - generate-ssh-keys
3B) Recommended: Entra ID + Azure RBAC
az aks create -g "$RG" -n "$AKS" -l "$REGION" \
 - enable-managed-identity \
 - assign-identity "$UAI_ID" \
 - assign-kubelet-identity "$UAI_ID" \
 - network-plugin azure - network-plugin-mode overlay - pod-cidr 10.240.0.0/16 \
 - vnet-subnet-id "$SUBNET_ID" - vm-set-type VirtualMachines \
 - nodepool-name systempool - node-vm-size "$SIZE" - node-count 1 \
 - enable-addons monitoring - workspace-resource-id "$WORKSPACE_ID" \
 - auto-upgrade-channel none - node-os-upgrade-channel NodeImage \
 - enable-aad - enable-azure-rbac - disable-local-accounts \
 - generate-ssh-keys
You can omit — disable-local-accounts initially, verify access, then disable.
4) Add a User node pool
az aks nodepool add -g "$RG" - cluster-name "$AKS" \
 -n userpool - mode User \
 - node-vm-size "$SIZE" \
 - node-count 1
5) Role Planes — Network vs Control Plane (ARM) vs In‑Cluster (Azure RBAC)
AKS access spans three planes. Assign roles at the right scope:
5.1 Network plane (BYO VNet)
    • Who: kubelet identity (UAMI) — manages NIC/IPs on the node subnet.
    • Role: Network Contributor
    • Scope: Subnet ($SUBNET_ID)
az role assignment create \
 - assignee-object-id "$UAI_PID" - assignee-principal-type ServicePrincipal \
 - role "Network Contributor" - scope "$SUBNET_ID"
5.2 Control Plane (ARM)
    • Purpose: download kubeconfig / user credentials (e.g., az aks get-credentials).
    • Role: Azure Kubernetes Service Cluster User Role (or Cluster Admin Role for admin creds).
    • Scope: AKS resource ($AKS_ID).
# Jump VM system-assigned MI (example objectId)
 az role assignment create - assignee "822b874a-861a-4d53-a939-e728c3fe0580" \
 - role "Azure Kubernetes Service Cluster User Role" - scope "$AKS_ID"
 
 # Group (if members should run az aks get-credentials)
 az role assignment create \
 - assignee-object-id "$GROUP_ID" - assignee-principal-type Group \
 - role "Azure Kubernetes Service Cluster User Role" - scope "$AKS_ID"
5.3 In‑Cluster (Azure RBAC for Kubernetes / kubectl)
    • Purpose: governs what principals can do with kubectl.
    • Roles: AKS RBAC Reader | Writer | Admin | Cluster Admin.
    • Scope: AKS resource ($AKS_ID).
#Group as cluster admins (broadest)
 az role assignment create \
 - assignee-object-id "$GROUP_ID" - assignee-principal-type Group \
 - role "Azure Kubernetes Service RBAC Cluster Admin" - scope "$AKS_ID"
 
 # Jump VM MI (start with Reader; upgrade as needed)
 az role assignment create - assignee "822b874a-861a-4d53-a939-e728c3fe0580" \
 - role "Azure Kubernetes Service RBAC Reader" - scope "$AKS_ID"


6) Jump Server (Ubuntu) — kubectl + snap kubelogin (MSI) 
Remember my article Cheap & Private: A Jump Server’s Azure Key Vault Playbook? You probablly not, but since we’re saving costs here we won’t deploy no s2s VPN or express route, we’ll configure a minimal linux jump server to accecss kubectl and monitor the pods and nodes from there privately. 
6A) Install tools
# kubectl
 sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
 sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
 echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
 sudo apt-get update && sudo apt-get install -y kubectl
 
 # kubelogin (snap)
 sudo snap install kubelogin
 which kubelogin # /snap/bin/kubelogin
6B) Get kubeconfig & switch to MSI auth (no device-code, no DNS)
az aks get-credentials -g "$RG" -n "$AKS" - overwrite-existing
 chmod 600 ~/.kube/config
 
 # Convert kubeconfig to MSI
 kubelogin convert-kubeconfig -l msi - kubeconfig ~/.kube/config
 
 # Ensure exec plugin uses snap kubelogin and has a safe PATH
 sed -i 's|command: .*kubelogin|command: /snap/bin/kubelogin|' ~/.kube/config
 awk '/exec:/{in=1} in&&/apiVersion:/{print;print " env:\n - name: PATH\n value: /usr/bin:/usr/local/bin:/bin:/snap/bin";next} {print}' \
 ~/.kube/config > ~/.kube/config.new && mv ~/.kube/config.new ~/.kube/config
If the jump VM uses a User‑Assigned MI, insert its clientId after - login msi:
sed -i '/- - login[[:space:]]\+msi/a\ - - client-id\n - <YOUR_UAMI_CLIENT_ID>' ~/.kube/config
6C) Test (MSI)
az login - identity
 az account set - subscription "$SUB"
 
 kubectl auth can-i list nodes
 kubectl get nodes
 kubectl get pods -A
7) Verification & Useful Queries
# AKS resource ID
 AKS_ID=$(az aks show -g "$RG" -n "$AKS" - query id -o tsv)
 
 # (Network) UAMI on the subnet
 UAMI_NAME="aks_test_02-uami"
 UAMI_OBJECT_ID=$(az identity show -g "$RG" -n "$UAMI_NAME" - query principalId -o tsv)
 az role assignment list - assignee-object-id "$UAMI_OBJECT_ID" - scope "$SUBNET_ID" \
 - query "[].{Role:roleDefinitionName,Scope:scope}" -o table
 
 # (Control plane & In‑cluster) Jump VM MI at AKS scope
 OBJ="822b874a-861a-4d53-a939-e728c3fe0580"
 az role assignment list - assignee "$OBJ" - scope "$AKS_ID" \
 - query "[].{Role:roleDefinitionName,Scope:scope}" -o table
 
 # Group RBAC at AKS scope
 GROUP_NAME="aks_users"
 GROUP_ID=$(az ad group show - group "$GROUP_NAME" - query id -o tsv)
 az role assignment list - assignee-object-id "$GROUP_ID" - scope "$AKS_ID" \
 - query "[].{Role:roleDefinitionName,Scope:scope}" -o table
 az ad group member list - group "$GROUP_ID" \
 - query "[].{displayName:displayName,id:id,upn:userPrincipalName}" -o table

8) Troubleshooting (field notes)
    • vCPU quota: change size (e.g., Standard_B2s) or request quota in mexicocentral.
    •  — nodepool-mode System unrecognized: first pool defaults to System on some CLI versions; omit the flag.
    • SSH key required: add — generate-ssh-keys.
    • Device‑code prompts/headless: use kubelogin convert-kubeconfig -l msi or correct arg order (get-token before — login).
    • DNS issues: MSI mode avoids DNS; otherwise fix /etc/resolv.conf or systemd-resolved.
    • ~/.kube/config mode warning: chmod 600 ~/.kube/config.
    • command must be specified … exec plugin: re‑pull kubeconfig and ensure exec.command: /snap/bin/kubelogin exists.
    • Snap vs local kubelogin: prefer absolute command: path and add env: PATH under the exec block.
9) Bonus: AKS Troubleshooting — What to Look For, Fast
0. Login and Prechecks (2 min)
az aks get-credentials -g "$RG" -n "$AKS" - overwrite-existing
kubelogin convert-kubeconfig -l azurecli # or -l msi on jump host
az account show - query user.name -o tsv
kubectl config current-context
kubectl auth can-i - list | head -n 30
    1. Api & Control Plane (2 min)
kubectl cluster-info
kubectl version - short
kubectl get - raw='/readyz?verbose'
2) Nodes & capacity (3 min)
kubectl get nodes -o wide
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .status.conditions[?(@.type=="Ready")]}{.status}{"\n"}{end}{end}'
Hotspots: CPU/Mem pressure (needs metrics-server)
kubectl top nodes
kubectl describe node <node>
Workloads:
kubectl get pods -A -o wide
kubectl get deploy,ds,sts -A -o wide
kubectl get events -A - sort-by=.lastTimestamp | tail -n 50
Stuck or crashy pods
kubectl get pods -A - field-selector=status.phase=Pending
# CrashLoopBackOff quick list (jq optional)
kubectl get pods -A -o json | jq -r '.items[] | select(any(.status.containerStatuses[]?; .state.waiting.reason=="CrashLoopBackOff")) | [.metadata.namespace,.metadata.name] | @tsv'
Conclusion — When (and why) to choose AKS with UAMI & private networking
    • Why AKS (vs. Container Apps):
 Choose AKS when you need full Kubernetes control: custom CNIs (Azure CNI Overlay), daemonsets, privileged workloads, fine-grained PodSecurity/NetworkPolicy, specialized ingress, GPU/TA, or multi-tenant platform engineering (GitOps, operators, CRDs). AKS gives you the knobs to build a platform; Container Apps optimizes for developer velocity with less ops — great for stateless/microservices, scale-to-zero, Dapr sidecars, jobs, and simple internal endpoints — without you managing nodes, CNIs, or upgrades.
    • Why User-Assigned Managed Identity (UAMI):
 Deterministic IAM and clean separation of duties. A UAMI decouples app/cluster permissions from ephemeral system identities and lets you:
    • Assign least-privilege roles precisely (Subnet Network Contributor to kubelet; AKS-scope Azure RBAC to users/VMs).
    • Rotate or swap identities without re-creating the cluster.
    • Audit exactly which identity touched which resource.
    • Private networking won’t work with a system identity. 
    • Why private networking (BYO VNet + CNI Overlay):
 Keep the control plane and data plane off the public internet, enforce egress through private paths, and integrate with enterprise routing, firewalls, and Private Link. Overlay mode simplifies IP management at scale while still giving Pod-level IPs and NSGs where needed.
    • When not to use AKS:
 If it’s a simple web/API or background job with standard autoscaling and no deep K8s requirements, Container Apps (or even App Service/Functions) will be faster to ship, cheaper to operate, and easier for small teams. AKS adds operational complexity (node images, upgrades, CNI, quotas, RBAC, observability) you don’t need for a “hello world” or a single microservice.
Bottom line:
 Use AKS + UAMI + private networking when you’re building a platform that needs strict network boundaries, enterprise IAM, and K8s-level extensibility. Use Container Apps when you just want to run containers with minimal ops.
