#!/usr/bin/env bash
# =============================================================================
# KUBECTL MONITORING CHEATSHEET – drop-in for your repo
# Focus: quick visibility, health checks, and live watching.
# NOTE: Some commands use JSONPath; a few optional ones use `jq` if installed.
# =============================================================================

# -----------------------------------------------------------------------------
# 1) Connecting to the aks standard call
# -----------------------------------------------------------------------------
#Basic kubectl needs IMPORTANT BEFORE ALL
#install Kubelet
az aks install-cli 
#configure kubectl to connect to your clusters
az aks get-credentials --resource-group <ResourceGroupName> --name <ClusterName>
# Login with VM MSI and test
az login --identity
az account set --subscription "$SUB"
#login to kubectl
kubelogin convert-kubeconfig -l azurecli


kubectl auth can-i list nodes
kubectl get nodes
kubectl get pods -A

# -----------------------------------------------------------------------------
# 1) Cluster & API basics
# -----------------------------------------------------------------------------
kubectl cluster-info                    # API/server endpoints
kubectl version --short                 # client/server versions
kubectl get --raw='/readyz?verbose'    # API server readiness details

# -----------------------------------------------------------------------------
# 1.2) Nodes – health, capacity & usage
# -----------------------------------------------------------------------------
kubectl get nodes -o wide
kubectl describe nodes <node-name>
kubectl top nodes                       # requires metrics-server
# Node Ready summary (JSONPath)
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .status.conditions[?(@.type=="Ready")]}{.status}{"\n"}{end}{end}'
# NotReady nodes (optional jq)
kubectl get nodes -o json | jq -r '.items[] | select(any(.status.conditions[]; .type=="Ready" and .status!="True")) | .metadata.name'

# -----------------------------------------------------------------------------
# 2) Namespaces – quick look
# -----------------------------------------------------------------------------
kubectl get ns
kubectl get ns --show-labels
# Pods per namespace (count)
kubectl get pods -A --no-headers | awk '{print $1}' | sort | uniq -c | sort -nr

# -----------------------------------------------------------------------------
# 3) Workloads – Deployments, DaemonSets, StatefulSets, ReplicaSets
# -----------------------------------------------------------------------------
kubectl get deploy,ds,sts -A -o wide
kubectl rollout status deploy/<name> -n <ns>
kubectl rollout history deploy/<name> -n <ns>
kubectl describe deploy/<name> -n <ns>
# Quick desired/ready check across all deployments
kubectl get deploy -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,READY:.status.readyReplicas/DESIRED:.spec.replicas,AGE:.metadata.creationTimestamp'

# -----------------------------------------------------------------------------
# 4) Services, Endpoints & Ingress
# -----------------------------------------------------------------------------
kubectl get svc -A -o wide
kubectl get endpoints,endpointslices -A
kubectl get ingress -A
# Show LB services with external IP/ports
kubectl get svc -A --field-selector spec.type=LoadBalancer -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,EXTERNAL-IP:.status.loadBalancer.ingress[*].ip,HOSTNAME:.status.loadBalancer.ingress[*].hostname,PORTS:.spec.ports[*].port'

# -----------------------------------------------------------------------------
# 5) Pods – listings, filters, wide view
# -----------------------------------------------------------------------------
kubectl get pods -A -o wide
kubectl get pods -n <ns> -o wide
kubectl get pods --field-selector=spec.nodeName=<node> -A         # pods on a node
kubectl get pods -A --field-selector=status.phase=Pending
kubectl get pods -A -l app=<label> -o wide                         # by label
# Show restarts & node in a compact table
kubectl get pods -A -o custom-columns='NS:.metadata.namespace,POD:.metadata.name,STATUS:.status.phase,RESTARTS:.status.containerStatuses[*].restartCount,NODE:.spec.nodeName' | column -t
# Pods NOT Running (optional jq)
kubectl get pods -A -o json | jq -r '.items[] | select(.status.phase!="Running") | [.metadata.namespace,.metadata.name,.status.phase] | @tsv'

# -----------------------------------------------------------------------------
# 6) Live watch – changes in real time
# -----------------------------------------------------------------------------
kubectl get pods -A -w
kubectl get deploy -A -w
# Watch a single namespace & sort (requires `watch`)
watch -n 2 'kubectl get pods -n <ns> -o wide --no-headers | sort'

# -----------------------------------------------------------------------------
# 7) Events – sorted & scoped
# -----------------------------------------------------------------------------
kubectl get events -A --sort-by=.lastTimestamp
kubectl get events -n <ns> --sort-by=.lastTimestamp
# Events for one object
kubectl describe pod/<pod> -n <ns> | sed -n "/Events:/,/^\s*$/p"
# k8s 1.27+: `kubectl events` (if available)
kubectl events -A || true

# -----------------------------------------------------------------------------
# 8) Logs – snapshot, stream, selectors
# -----------------------------------------------------------------------------
kubectl logs <pod> -n <ns>                           # current container
kubectl logs <pod> -c <container> -n <ns>            # specific container
kubectl logs -f <pod> -n <ns>                        # stream
kubectl logs <pod> -n <ns> --since=30m               # last 30 minutes
kubectl logs <pod> -n <ns> --timestamps
# All pods by label (parallel streaming; adjust max-log-requests)
kubectl logs -l app=<label> -n <ns> --all-containers=true --max-log-requests=20 --tail=100
# Previous container crash logs
kubectl logs <pod> -n <ns> -p

#get logs for all pods with a speific label
kubectl logs -l <labelkey>=<labelvalue>
# -----------------------------------------------------------------------------
# 9) Exec – quick probes in running containers
# -----------------------------------------------------------------------------
kubectl exec -it <pod> -n <ns> -- sh -c 'env | sort'
kubectl exec -it <pod> -n <ns> -- sh -c 'ip addr; ip route'
kubectl exec -it <pod> -n <ns> -- nc -vz <host> <port> || true

# -----------------------------------------------------------------------------
# 10) Health / readiness signals
# -----------------------------------------------------------------------------
# Show container ready status & last state
kubectl get pods -A -o custom-columns='NS:.metadata.namespace,POD:.metadata.name,READY:.status.containerStatuses[*].ready,LAST-STATE:.status.containerStatuses[*].lastState'
# CrashLoopBackOff quick list (optional jq)
kubectl get pods -A -o json | jq -r '.items[] | select(any(.status.containerStatuses[]?; .state.waiting.reason=="CrashLoopBackOff")) | [.metadata.namespace,.metadata.name] | @tsv'
# Image versions running
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{range .spec.containers[*]}{.image}{" "}{end}{"\n"}{end}'

# -----------------------------------------------------------------------------
# 11) Autoscaling – HPA overview
# -----------------------------------------------------------------------------
kubectl get hpa -A
kubectl describe hpa/<name> -n <ns>

# -----------------------------------------------------------------------------
# 12) Network Policies – quick scan
# -----------------------------------------------------------------------------
kubectl get netpol -A
kubectl describe netpol/<name> -n <ns>

# -----------------------------------------------------------------------------
# 13) Storage – PVC/PV bound state
# -----------------------------------------------------------------------------
kubectl get pvc -A
kubectl get pv
kubectl describe pvc/<name> -n <ns>

# -----------------------------------------------------------------------------
# 14) Rollouts & restarts – deploy/daemonset helpers
# -----------------------------------------------------------------------------
kubectl rollout status deploy/<name> -n <ns>
kubectl rollout restart deploy/<name> -n <ns>        # trigger new pods
kubectl rollout status ds/<name> -n <ns>

# -----------------------------------------------------------------------------
# 15) Sort & format – handy `get` combinations
# -----------------------------------------------------------------------------
# Sort pods by name
kubectl get pods -A --sort-by=.metadata.name
# Newest-first by start time
kubectl get pods -A --sort-by=.status.startTime
# Wide with labels
kubectl get pods -A -o wide --show-labels
# Custom columns (name, node, IP, phase, restarts)
kubectl get pods -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,NODE:.spec.nodeName,IP:.status.podIP,PHASE:.status.phase,RESTARTS:.status.containerStatuses[*].restartCount' | column -t

# -----------------------------------------------------------------------------
# 16) API resources & capabilities
# -----------------------------------------------------------------------------
kubectl api-resources
kubectl api-versions
kubectl explain pod --recursive | less

# -----------------------------------------------------------------------------
# 17) Troubleshooting “hot keys”
# -----------------------------------------------------------------------------
kubectl describe pod/<pod> -n <ns>
kubectl get pod/<pod> -n <ns> -o yaml | less
kubectl get events -n <ns> --sort-by=.lastTimestamp | tail -n 50
kubectl get endpoints/<svc> -n <ns> -o yaml
kubectl get svc/<svc> -n <ns> -o wide

# -----------------------------------------------------------------------------
# 18) Metrics quick sweep (if metrics-server present)
# -----------------------------------------------------------------------------
kubectl top pods -A
kubectl top pods -A --containers
kubectl top pods -n <ns> --sort-by=cpu
kubectl top pods -n <ns> --sort-by=memory

# -----------------------------------------------------------------------------
# 19) Namespaced defaults (so you type less)
# -----------------------------------------------------------------------------
kubectl config set-context --current --namespace=<ns>
kubectl config view --minify | grep namespace


# -----------------------------------------------------------------------------
# 20) Bonus: watch restarts and non-running pods (simple)
# -----------------------------------------------------------------------------
watch -n 3 'kubectl get pods -A -o custom-columns="NS:.metadata.namespace,POD:.metadata.name,PHASE:.status.phase,RESTARTS:.status.containerStatuses[*].restartCount" --no-headers | sort'
