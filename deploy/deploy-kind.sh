#!/bin/bash

echo "Crearting local kind cluster ..."

cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF

echo "Cluster created."
echo "Sleeping for 30 secs to wait for the node to be up ...."
sleep 30
echo "Done."

echo "Installing ingress-nginx ..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
echo "Waiting until nginx-ingress is fully installed ..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
echo "ingress-nginx installed."

echo "Deploying argocd ..."
kubectl create namespace argocd
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argocd/argo-cd -f argocd-helm-chart-values.yaml -n argocd
echo "Waiting until argocd is fully installed ..."
kubectl wait -n argocd --for=condition=ready pod --selector=app.kubernetes.io/name=argocd-server --timeout=90s
kubectl apply -f argocd-ingress.yaml
kubectl apply -f hello-world-sample-application.yaml
echo "argocd installed."

echo "Installing istio ..."
kubectl create namespace istio-system
helm install istio-base istio/base --version=1.18.2 -n istio-system
helm install istio-operator istio/istiod --version=1.18.2 -n istio-system
echo "Waiting until istiod is fully installed ..."
kubectl wait -n istio-system --for=condition=ready pod --selector=app=istiod --timeout=90s
echo "istiod installed."
helm install istio-gateway istio/gateway --version=1.18.2 -n istio-system
echo "Waiting until istio-gateway is fully installed ..."
kubectl wait -n istio-system --for=condition=ready pod --selector=app=istio-gateway --timeout=90s
kbectl apply -f .. 
echo "istio-gateway installed."

