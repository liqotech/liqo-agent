package logic

import (
	"github.com/liqotech/liqo-agent/internal/tray-agent/agent/client"
	app "github.com/liqotech/liqo-agent/internal/tray-agent/app-indicator"
	"sync"
)

//this file contains the callback functions for the Indicator listeners

//******* PEERS *******

func listenAddedOrUpdatedPeer(data client.NotifyDataGeneric, _ ...interface{}) {
	i := app.GetIndicator()
	status := i.Status()
	fcData, ok := data.(*client.NotifyDataForeignCluster)
	if !ok {
		panic("wrong NotifyData type for an event Listener")
	}
	//1- store information on Indicator Status
	peer := status.AddOrUpdatePeer(fcData)
	peer.RLock()
	defer peer.RUnlock()
	//update content of the Status MenuNode in the tray menu
	i.RefreshStatus()

	//2- update information on tray menu
	quickNode, present := i.Quick(qPeers)
	if !present {
		return
	}
	peerNode, present := quickNode.ListChild(peer.ClusterID)
	if !present {
		peerNode = createPeerNode(quickNode, fcData, peer)
	}
	wg := &sync.WaitGroup{}
	wg.Add(2)
	go refreshPeerInfo(peerNode, peer, fcData, wg)
	go refreshPeeringInfo(peerNode, peer, fcData, wg)
	wg.Wait()
	refreshPeerCount(quickNode)

	//3- notify selected events
	if !present {
		if peer.OutPeeringConnected {
			i.NotifyPeering(app.PeeringOutgoing, app.NotifyEventPeeringOn, peer)
		}
		if peer.InPeeringConnected {
			i.NotifyPeering(app.PeeringIncoming, app.NotifyEventPeeringOn, peer)
		}
	} else {
		if !fcData.OutPeering.Connected && peer.OutPeeringConnected {
			i.NotifyPeering(app.PeeringOutgoing, app.NotifyEventPeeringOn, peer)
		} else if fcData.OutPeering.Connected && !peer.OutPeeringConnected {
			i.NotifyPeering(app.PeeringOutgoing, app.NotifyEventPeeringOff, peer)
		}
		if !fcData.InPeering.Connected && peer.InPeeringConnected {
			i.NotifyPeering(app.PeeringIncoming, app.NotifyEventPeeringOn, peer)
		} else if fcData.InPeering.Connected && !peer.InPeeringConnected {
			i.NotifyPeering(app.PeeringIncoming, app.NotifyEventPeeringOff, peer)
		}
	}
}

func listenDeletedPeer(data client.NotifyDataGeneric, _ ...interface{}) {
	i := app.GetIndicator()
	status := i.Status()
	fcData, ok := data.(*client.NotifyDataForeignCluster)
	if !ok {
		panic("wrong NotifyData type for an event Listener")
	}
	//1- update peer data
	peer := status.RemovePeer(fcData)
	peer.RLock()
	defer peer.RUnlock()
	//update content of the Status MenuNode in the tray menu
	i.RefreshStatus()

	//2- update information on tray menu
	quickNode, present := i.Quick(qPeers)
	if !present {
		return
	}
	_, present = quickNode.ListChild(peer.ClusterID)
	if present {
		//remove peer node and all its sub elements
		quickNode.FreeListChild(peer.ClusterID)
	}
	refreshPeerCount(quickNode)

	//3- notify selected events
	if !fcData.OutPeering.Connected && peer.OutPeeringConnected {
		i.NotifyPeering(app.PeeringOutgoing, app.NotifyEventPeeringOn, peer)
	} else if fcData.OutPeering.Connected && !peer.OutPeeringConnected {
		i.NotifyPeering(app.PeeringOutgoing, app.NotifyEventPeeringOff, peer)
	}
	if !fcData.InPeering.Connected && peer.InPeeringConnected {
		i.NotifyPeering(app.PeeringIncoming, app.NotifyEventPeeringOn, peer)
	} else if fcData.InPeering.Connected && !peer.InPeeringConnected {
		i.NotifyPeering(app.PeeringIncoming, app.NotifyEventPeeringOff, peer)
	}

}

func listenClusterName(data client.NotifyDataGeneric, _ ...interface{}) {
	clusterName, ok := data.(string)
	if !ok {
		panic("wrong NotifyData type for an event Listener")
	}
	i := app.GetIndicator()
	status := i.Status()
	status.SetClusterName(clusterName)
	i.RefreshStatus()
}
