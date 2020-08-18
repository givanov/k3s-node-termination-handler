package handler

import (
	"context"
	"github.com/givanov/k3s-node-termination-handler/pkg/flags"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/cloud-provider/node/helpers"
	"sigs.k8s.io/controller-runtime/pkg/client"
	logf "sigs.k8s.io/controller-runtime/pkg/log"
	"time"
)

var log = logf.Log.WithName("nodeTermination")

type nodeTermination struct {
	client client.Client
}

func New(client client.Client) NodeTermination {
	return &nodeTermination{client}
}

func (n *nodeTermination) ReconcileNodeStatus(node *corev1.Node) error {
	_, readyCondition := helpers.GetNodeCondition(&node.Status, corev1.NodeReady)
	if readyCondition.Status == corev1.ConditionUnknown {
		timeSpentAsNotReady := time.Since(readyCondition.LastTransitionTime.Time)
		if timeSpentAsNotReady > flags.NodeTerminationGracePeriod {
			log.Info("Identified not ready node outside grace period. Deleting", "Node", node.Name, "SecondsNotReady", timeSpentAsNotReady)
			err := n.client.Delete(context.TODO(), node)
			if err != nil {
				return err
			}
		} else {
			log.Info("Identified not ready node within grace period", "Node", node.Name, "SecondsNotReady", timeSpentAsNotReady)
		}
	}

	return nil
}
