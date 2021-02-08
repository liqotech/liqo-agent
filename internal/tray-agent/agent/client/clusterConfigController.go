package client

import (
	clusterConfig "github.com/liqotech/liqo/apis/config/v1alpha1"
)

//createClusterConfigController creates a new CRDController for the Liqo ClusterConfig CRD.
func createClusterConfigController(kubeconfig string) (*CRDController, error) {
	controller := &CRDController{
		addFunc:    clusterConfigAddFunc,
		updateFunc: clusterConfigUpdateFunc,
	}
	//init client
	newClient, err := clusterConfig.CreateClusterConfigClient(kubeconfig, false)
	if err != nil {
		return nil, err
	}
	controller.CRDClient = newClient
	controller.resource = string(CRClusterConfig)
	return controller, nil
}

//clusterConfigAddFunc is the ADD event handler for the ClusterConfig CRDController.
func clusterConfigAddFunc(obj interface{}) {
	config := obj.(*clusterConfig.ClusterConfig)
	agentCtrl.NotifyChannel(ChanClusterName) <- getClusterName(config)
}

//clusterConfigUpdateFunc is the UPDATE event handler for the ClusterConfig CRDController.
func clusterConfigUpdateFunc(_ interface{}, newObj interface{}) {
	config := newObj.(*clusterConfig.ClusterConfig)
	agentCtrl.NotifyChannel(ChanClusterName) <- getClusterName(config)
}

//getClusterName extracts the ClusterName from a ClusterConfig CR.
func getClusterName(config *clusterConfig.ClusterConfig) string {
	return config.Spec.DiscoveryConfig.ClusterName
}
