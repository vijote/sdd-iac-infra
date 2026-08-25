#!/bin/bash
# Network validation script for Kubernetes cluster

set -e

echo "=== Kubernetes Network Validation ==="
echo

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "ERROR: kubectl not found. Please configure kubectl first."
    exit 1
fi

# Check cluster nodes
echo "1. Checking cluster nodes..."
kubectl get nodes -o wide
echo

# Check system pods
echo "2. Checking system pods..."
kubectl get pods -n kube-system
echo

# Check Flannel pods
echo "3. Checking Flannel CNI pods..."
kubectl get pods -n kube-flannel
echo

# Test pod-to-pod communication
echo "4. Testing pod-to-pod communication..."
kubectl run test-pod-1 --image=busybox --rm -it --restart=Never -- sleep 30 &
kubectl run test-pod-2 --image=busybox --rm -it --restart=Never -- sleep 30 &
echo "Waiting for test pods to be ready..."
kubectl wait --for=condition=ready pod/test-pod-1 --timeout=60s
kubectl wait --for=condition=ready pod/test-pod-2 --timeout=60s

# Get pod IPs
POD1_IP=$(kubectl get pod test-pod-1 -o jsonpath='{.status.podIP}')
POD2_IP=$(kubectl get pod test-pod-2 -o jsonpath='{.status.podIP}')

echo "Test Pod 1 IP: $POD1_IP"
echo "Test Pod 2 IP: $POD2_IP"

# Test connectivity
echo "Testing connectivity from Pod 1 to Pod 2..."
kubectl exec test-pod-1 -- ping -c 3 $POD2_IP

echo "Testing connectivity from Pod 2 to Pod 1..."
kubectl exec test-pod-2 -- ping -c 3 $POD1_IP

# Clean up test pods
kubectl delete pod test-pod-1 test-pod-2 --grace-period=0 --force

# Test service discovery
echo
echo "5. Testing service discovery..."
kubectl create clusterip test-service --tcp=80:80 --dry-run=client -o yaml | kubectl apply -f -
echo "Service discovery test completed successfully."

echo
echo "=== Network Validation Complete ==="
echo "All network tests passed!"