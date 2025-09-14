#!/usr/bin/bash

kind create cluster

clusterctl init --infrastructure proxmox --ipam in-cluster --control-plane talos --bootstrap talos

# Wait for everything to be ready
kubectl -n cabpt-system rollout status deployment cabpt-controller-manager --watch --timeout=300s
kubectl -n cacppt-system rollout status deployment cacppt-controller-manager --watch --timeout=300s
kubectl -n capmox-system rollout status deployment capmox-controller-manager --watch --timeout=300s
kubectl -n capi-system rollout status deployment capi-controller-manager --watch --timeout=300s
kubectl -n capi-ipam-in-cluster-system rollout status deployment capi-ipam-in-cluster-controller-manager --watch --timeout=300s

kustomize build . | kubectl apply -f -
