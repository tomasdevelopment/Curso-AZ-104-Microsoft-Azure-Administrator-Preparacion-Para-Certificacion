# ------------------------------
# 0) GLOBAL VARS (EDIT THESE)
# ------------------------------
SUB="yoursuscriptionid"
RG="yourrg"
AKS="akstest"
REGION="mexicocentral"

VNET_RG="$RG"
VNET_NAME="yourrg-vnet"
SUBNET_NAME="default"

VNET_ID="/subscriptions/$SUB/resourceGroups/$VNET_RG/providers/Microsoft.Network/virtualNetworks/$VNET_NAME"
SUBNET_ID="${VNET_ID}/subnets/${SUBNET_NAME}"

# LA workspace (existing)
WORKSPACE_ID="/subscriptions/yoursuscriptionid/resourceGroups/DefaultResourceGroup-EUS/providers/Microsoft.OperationalInsights/workspaces/DefaultWorkspace-yoursuscriptionid-EUS"

SIZE="Standard_D2ps_v6"   # VM size for nodepools

# Example identities/users/groups used later in role assignments
UAMI_NAME="aks_test_02-uami"
GROUP_NAME="aks_users"
USER_UPN="you@example.com"  # change or use objectId directly
SPN_OBJID="systemid"    # sample SPN/MI objectId from your notes
JUMP_VM_MI_OBJID="systemid"  # same as above in your example block

# ---------------------------------
# 1) SUBSCRIPTION CONTEXT + CHECKS
# ---------------------------------
az account set --subscription "$SUB"
echo "Using subscription: $(az account show --query id -o tsv)"

# ---------------------------------
# 2) CREATE / RESOLVE UAMI FOR AKS
# ---------------------------------
# Create a single UAMI used for BOTH control plane and kubelet
az identity create -g "$RG" -n "$UAMI_NAME" -l "$REGION" || true
UAI_ID=$(az identity show -g "$RG" -n "$UAMI_NAME" --query id -o tsv)
UAI_PID=$(az identity show -g "$RG" -n "$UAMI_NAME" --query principalId -o tsv)
echo "UAMI created/resolved: $UAI_ID (principalId=$UAI_PID)"

# Kubelet needs Network Contributor on the NODE SUBNET
az role assignment create \
  --assignee-object-id "$UAI_PID" --assignee-principal-type ServicePrincipal \
  --role "Network Contributor" --scope "$SUBNET_ID" || true

# (Optional) If you’ll pull from ACR, also give AcrPull on your ACR (uncomment and set scope):
# az role assignment create --assignee-object-id "$UAI_PID" --assignee-principal-type ServicePrincipal \
#   --role "AcrPull" --scope "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.ContainerRegistry/registries/<acr>"

# ---------------------------------
# 3) AKS CREATE — VARIANT A (AAD + Azure RBAC + Monitoring)
# ---------------------------------
az aks create -g "$RG" -n "$AKS" -l "$REGION" \
  --enable-managed-identity \
  --assign-identity "$UAI_ID" \
  --assign-kubelet-identity "$UAI_ID" \
  --network-plugin azure \
  --network-plugin-mode overlay \
  --pod-cidr 10.240.0.0/16 \
  --vnet-subnet-id "$SUBNET_ID" \
  --vm-set-type VirtualMachines \
  --nodepool-name systempool \
  --node-vm-size "$SIZE" \
  --node-count 1 \
  --enable-addons monitoring \
  --workspace-resource-id "$WORKSPACE_ID" \
  --auto-upgrade-channel none \
  --node-os-upgrade-channel NodeImage \
  --generate-ssh-keys \
  --enable-aad \
  --enable-azure-rbac \
  --disable-local-accounts || true

# ---------------------------------
# 4) AKS CREATE — VARIANT B ("with local aks identity" — preserved)
#    This is effectively similar but without the AAD lines; kept to NOT lose anything.
# ---------------------------------
az aks create -g "$RG" -n "$AKS" -l "$REGION" \
  --enable-managed-identity \
  --assign-identity "$UAI_ID" \
  --assign-kubelet-identity "$UAI_ID" \
  --network-plugin azure \
  --network-plugin-mode overlay \
  --pod-cidr 10.240.0.0/16 \
  --vnet-subnet-id "$SUBNET_ID" \
  --vm-set-type VirtualMachines \
  --nodepool-name systempool \
  --node-vm-size "$SIZE" \
  --node-count 1 \
  --enable-addons monitoring \
  --workspace-resource-id "$WORKSPACE_ID" \
  --auto-upgrade-channel none \
  --node-os-upgrade-channel NodeImage \
  --generate-ssh-keys || true

# ---------------------------------
# 5) OPTIONAL: ADD A USER POOL (first occurrence)
# ---------------------------------
az aks nodepool add -g "$RG" --cluster-name "$AKS" -n userpool --mode User \
  --node-vm-size "$SIZE" --node-count 1 || true

# ---------------------------------
# 6) RBAC: ASSIGN GROUP/USER ROLES AT AKS SCOPE (Examples)
# ---------------------------------
GROUP_ID=$(az ad group show --group "$GROUP_NAME" --query id -o tsv || echo "")
AKS_ID=$(az aks show -g "$RG" -n "$AKS" --query id -o tsv)

# Example: give a GROUP cluster-admin rights
if [[ -n "$GROUP_ID" ]]; then
  az role assignment create \
    --assignee-object-id "$GROUP_ID" \
    --assignee-principal-type Group \
    --role "Azure Kubernetes Service RBAC Cluster Admin" \
    --scope "$AKS_ID" || true
fi

# Example: give a user read-only
USER_ID=$(az ad user show --id "$USER_UPN" --query id -o tsv || echo "")
if [[ -n "$USER_ID" ]]; then
  az role assignment create \
    --assignee "$USER_ID" \
    --role "Azure Kubernetes Service RBAC Reader" \
    --scope "$AKS_ID" || true
fi

# ---------------------------------
# 7) CONTROL PLANE ROLE for a specific SPN/MI (lets you call listClusterUserCredential/action)
# ---------------------------------
az role assignment create \
  --assignee "$SPN_OBJID" \
  --role "Azure Kubernetes Service Cluster User Role" \
  --scope "$AKS_ID" || true

# ---------------------------------
# 8) VERIFY IDENTITY & ACCESS — Show IDs and role assignments
# ---------------------------------
az identity show -g "$RG" -n "$UAMI_NAME" \
  --query "{objectId:principalId, resourceId:id, clientId:clientId, name:name}" -o table || true

UAMI_OBJECT_ID=$(az identity show -g "$RG" -n "$UAMI_NAME" --query principalId -o tsv)

# All role assignments for this UAMI (any scope)
az role assignment list --assignee-object-id "$UAMI_OBJECT_ID" -o table || true

# Specifically on your AKS resource
az role assignment list --assignee-object-id "$UAMI_OBJECT_ID" --scope "$AKS_ID" -o table || true

# Specifically on the VNet subnet (where we granted Network Contributor)
az role assignment list --assignee-object-id "$UAMI_OBJECT_ID" --scope "$SUBNET_ID" -o table || true

# ---------------------------------
# 9) IN-CLUSTER (Azure RBAC) — pick ONE of these for OBJ (example MI/SPN objectId)
# ---------------------------------
OBJ="$SPN_OBJID"  # reusing your sample objectId

# 1) Control-plane (ensure present)
az role assignment create --assignee "$OBJ" \
  --role "Azure Kubernetes Service Cluster User Role" \
  --scope "$AKS_ID" || true

# 2) In-cluster RBAC: CHOOSE ONLY ONE (examples preserved)
# Read-only:
az role assignment create --assignee "$OBJ" \
  --role "Azure Kubernetes Service RBAC Reader" \
  --scope "$AKS_ID" || true

# (Option A) Cluster Admin — simplest if you’re the owner
az role assignment create --assignee "$OBJ" \
  --role "Azure Kubernetes Service RBAC Cluster Admin" \
  --scope "$AKS_ID" || true

# (Option B) Narrower but powerful
az role assignment create --assignee "$OBJ" --role "Azure Kubernetes Service RBAC Admin" --scope "$AKS_ID"

# (Other alternatives)
az role assignment create --assignee "$OBJ" --role "Azure Kubernetes Service RBAC Writer" --scope "$AKS_ID"
az role assignment create --assignee "$OBJ" --role "Azure Kubernetes Service RBAC Admin" --scope "$AKS_ID"
az role assignment create --assignee "$OBJ" --role "Azure Kubernetes Service RBAC Cluster Admin" --scope "$AKS_ID"
