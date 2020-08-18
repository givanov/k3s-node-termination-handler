package handler

import (
	"context"
	"github.com/givanov/k3s-node-termination-handler/pkg/flags"
	"github.com/stretchr/testify/assert"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/client-go/kubernetes/scheme"
	"sigs.k8s.io/controller-runtime/pkg/client/fake"
	"testing"
	"time"
)

const (
	//nolint
	nodeName      = "node1"
)


func TestReconcileNodeStatus_DoesNothing_WhenAllNodesReady(t *testing.T) {
	s := scheme.Scheme

	lastTransitionTime := time.Now().Add(-5*time.Minute)

	node := &corev1.Node{
		ObjectMeta: metav1.ObjectMeta{
			Name:      nodeName,
		},
		Status: corev1.NodeStatus{Conditions: []corev1.NodeCondition{
			{
				Type: corev1.NodeReady,
				Status: corev1.ConditionTrue,
				LastTransitionTime: metav1.NewTime(lastTransitionTime),
			},
		}},
	}

	// Objects to track in the fake client.
	objs := []runtime.Object{
		node,
	}

	// Create a fake client to mock API calls.
	client := fake.NewFakeClientWithScheme(s, objs...)

	subject := New(client)

	err := subject.ReconcileNodeStatus(node)

	assert.NoError(t, err)

	namespacedName := types.NamespacedName{Name: nodeName}

	testNode := &corev1.Node{}
	err = client.Get(context.TODO(), namespacedName, testNode)
	assert.NoError(t, err)
	assert.False(t, errors.IsNotFound(err))

}

func TestReconcileNodeStatus_DoesNothing_WhenNodeHasNotBeenNotReadyLongEnough(t *testing.T) {
	s := scheme.Scheme

	flags.NodeTerminationGracePeriod = 20*time.Minute

	lastTransitionTime := time.Now().Add(-5*time.Minute)

	node := &corev1.Node{
		ObjectMeta: metav1.ObjectMeta{
			Name:      nodeName,
		},
		Status: corev1.NodeStatus{Conditions: []corev1.NodeCondition{
			{
				Type: corev1.NodeReady,
				Status: corev1.ConditionUnknown,
				LastTransitionTime: metav1.NewTime(lastTransitionTime),
			},
		}},
	}

	// Objects to track in the fake client.
	objs := []runtime.Object{
		node,
	}

	// Create a fake client to mock API calls.
	client := fake.NewFakeClientWithScheme(s, objs...)

	subject := New(client)

	err := subject.ReconcileNodeStatus(node)

	assert.NoError(t, err)

	namespacedName := types.NamespacedName{Name: nodeName}

	testNode := &corev1.Node{}
	err = client.Get(context.TODO(), namespacedName, testNode)
	assert.NoError(t, err)
	assert.False(t, errors.IsNotFound(err))

}

func TestReconcileNodeStatus_DeletesNode_WhenNodeHasBeenNotReadyLongEnough(t *testing.T) {
	s := scheme.Scheme

	flags.NodeTerminationGracePeriod = 20*time.Minute

	lastTransitionTime := time.Now().Add(-21*time.Minute)

	node := &corev1.Node{
		ObjectMeta: metav1.ObjectMeta{
			Name:      nodeName,
		},
		Status: corev1.NodeStatus{Conditions: []corev1.NodeCondition{
			{
				Type: corev1.NodeReady,
				Status: corev1.ConditionUnknown,
				LastTransitionTime: metav1.NewTime(lastTransitionTime),
			},
		}},
	}

	// Objects to track in the fake client.
	objs := []runtime.Object{
		node,
	}

	// Create a fake client to mock API calls.
	client := fake.NewFakeClientWithScheme(s, objs...)

	subject := New(client)

	err := subject.ReconcileNodeStatus(node)

	assert.NoError(t, err)

	namespacedName := types.NamespacedName{Name: nodeName}

	testNode := &corev1.Node{}
	err = client.Get(context.TODO(), namespacedName, testNode)
	assert.Error(t, err)
	assert.True(t, errors.IsNotFound(err))

}