#!/bin/bash
set -e

IMAGE="fatehphd/web-project:latest"
APP="web-project"

# 1. Verify cluster connectivity and display node status
echo "===== Cluster info ====="
kubectl cluster-info
kubectl get nodes

# 2. Create the deployment from the Docker Hub image (skip if it exists)
echo "===== Deployment ====="
if kubectl get deployment "$APP" >/dev/null 2>&1; then
  echo "Deployment $APP already exists - updating image"
  kubectl set image deployment/"$APP" "$APP"="$IMAGE"
  kubectl rollout restart deployment/"$APP"
else
  kubectl create deployment "$APP" --image="$IMAGE"
fi

# 3. Expose the deployment as a NodePort service on container port 80
echo "===== Service ====="
if kubectl get service "$APP" >/dev/null 2>&1; then
  echo "Service $APP already exists"
else
  kubectl expose deployment "$APP" --type=NodePort --port=80
  kubectl patch service "$APP" -p '{"spec":{"ports":[{"port":80,"nodePort":30080}]}}'
fi

# 4. Scale the deployment to 3 replicas
echo "===== Scaling ====="
kubectl scale deployment "$APP" --replicas=3
kubectl rollout status deployment/"$APP" --timeout=180s

# 5. Display verification
echo "===== Pods ====="
kubectl get pods -o wide
echo "===== Deployments ====="
kubectl get deployments
echo "===== Services ====="
kubectl get services
