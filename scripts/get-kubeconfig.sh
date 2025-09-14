#!/usr/bin/bash

kubectl get secret aliktb-dev-cluster-kubeconfig -o yaml | yq .data.value | base64 -d > kubeconfig
