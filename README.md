# k3s-node-termination-handler

## Overview

k3s-node-termination-handler is a Kubernetes operator that deletes nodes if their readiness is Unknown for a specified amount of time.
The usecase this was build for was when nodes die, k3s never removes them and as such pods get stuck on the phantom node

## Deployment
### Deploy the operator

Deploy the operator dependencies:
```
kubectl apply -f deploy/service_account.yaml -n k3s-node-termination-handler
kubectl apply -f deploy/role.yaml -n k3s-node-termination-handler
kubectl apply -f deploy/role_binding.yaml -n k3s-node-termination-handler
```

Deploy the operator:
```
kubectl apply -f deploy/deployment.yaml -n k3s-node-termination-handler
```

### Deploying via helm chart

#### Without existing credentials secret
```
helm upgrade --install k3s-node-termination-handler https://github.com/givanov/k3s-node-termination-handler/releases/download/${VERSION}/k3s-node-termination-handler-${VERSION}.tgz \
    -n k3s-node-termination-handler \
    --set nodeTerminationGracePeriod=5m
```
Where ${VERSION} is the version you want to install


helm upgrade --install k3s-node-termination-handler https://github.com/givanov/k3s-node-termination-handler/releases/download/v1.0.0/k3s-node-termination-handler-v1.0.0.tgz -n k3s-node-termination-handler \
    --set nodeTerminationGracePeriod=5m