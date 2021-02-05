package client

import (
	"errors"
	discovery "github.com/liqotech/liqo/apis/discovery/v1alpha1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

//StartStopOutPeering interacts with a ForeignCluster to trigger the procedure to establish a peering towards
//a peer (start = true) or to stop it if already active.
func (ctrl *AgentController) StartStopOutPeering(foreignCluster string, start bool) error {
	fcCtrl := ctrl.Controller(CRForeignCluster)
	obj, exist, err := fcCtrl.Store.GetByKey(foreignCluster)
	if err != nil {
		return err
	}
	if !exist {
		return errors.New("no such ForeignCluster found")
	}
	fc := obj.(*discovery.ForeignCluster)
	fc.Spec.Join = start
	_, err = fcCtrl.Resource(string(CRForeignCluster)).Update(foreignCluster, fc, metav1.UpdateOptions{})
	return err
}
