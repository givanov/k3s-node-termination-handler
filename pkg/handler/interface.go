package handler

import (
	corev1 "k8s.io/api/core/v1"
)

type NodeTermination interface {
	ReconcileNodeStatus(node *corev1.Node) error
}

