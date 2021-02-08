package logic

import (
	"github.com/liqotech/liqo-agent/internal/tray-agent/agent/client"
	app "github.com/liqotech/liqo-agent/internal/tray-agent/app-indicator"
	"github.com/skratchdot/open-golang/open"
)

//OnReady is the routine orchestrating Liqo Agent execution.
func OnReady() {
	// Indicator configuration
	i := app.GetIndicator()
	i.RefreshStatus()
	startListenerClusterConfig(i)
	startListenerPeersList(i)
	startQuickOnOff(i)
	startQuickChangeMode(i)
	startQuickDashboard(i)
	startQuickShowPeers(i)
	i.AddSeparator()
	startQuickSetNotifications(i)
	startQuickLiqoWebsite(i)
	startQuickQuit(i)
	//try to start Liqo and main ACTION
	quickTurnOnOff(i)
}

//OnExit is the routine containing clean-up operations to be performed at Liqo Agent exit.
func OnExit() {
	app.GetIndicator().Disconnect()
}

//startQuickOnOff is the wrapper function to register the QUICK "START/STOP LIQO".
func startQuickOnOff(i *app.Indicator) {
	i.AddQuick("", qOnOff, func(args ...interface{}) {
		quickTurnOnOff(args[0].(*app.Indicator))
	}, i)
	//the Quick MenuNode title is refreshed
	updateQuickTurnOnOff(i)
}

//startQuickChangeMode is the wrapper function to register the QUICK "CHANGE LIQO MODE"
func startQuickChangeMode(i *app.Indicator) {
	i.AddQuick("", qMode, func(args ...interface{}) {
		quickChangeMode(i)
	}, i)
	//the Quick MenuNode title is refreshed
	updateQuickChangeMode(i)
}

//startQuickLiqoWebsite is the wrapper function to register QUICK "About Liqo".
func startQuickLiqoWebsite(i *app.Indicator) {
	i.AddQuick("Help", qWeb, func(args ...interface{}) {
		_ = open.Start("https://doc.liqo.io/")
	})
}

//startQuickDashboard is the wrapper function to register QUICK "LAUNCH Liqo Dash".
func startQuickDashboard(i *app.Indicator) {
	node := i.AddQuick("LiqoDash", qDash, func(args ...interface{}) {
		quickConnectDashboard(i)
	})
	node.SetIsEnabled(false)
}

//startQuickSetNotifications is the wrapper function to register QUICK "Change Notification settings".
func startQuickSetNotifications(i *app.Indicator) {
	i.AddQuick("Notifications Settings", qNotify, func(args ...interface{}) {
		quickChangeNotifyLevel()
	})
}

//startQuickQuit is the wrapper function to register QUICK "QUIT".
func startQuickQuit(i *app.Indicator) {
	i.AddQuick("Quit", qQuit, func(args ...interface{}) {
		i := args[0].(*app.Indicator)
		i.Quit()
	}, i)
}

//startQuickShowPeers is the wrapper function to register QUICK "PEERS".
func startQuickShowPeers(i *app.Indicator) {
	node := i.AddQuick(titlePeers, qPeers, nil)
	refreshPeerCount(node)
}

//LISTENERS

/*startListenerPeersList is a wrapper that starts the listeners regarding the dynamic listing of Liqo discovered Liqo peers.
  Since these listeners work on a specific QUICK MenuNode, the associated handlers works only if that QUICK
  is registered in the Indicator.*/
func startListenerPeersList(i *app.Indicator) {
	i.Listen(client.ChanPeerAddedOrUpdated, listenAddedOrUpdatedPeer)
	i.Listen(client.ChanPeerDeleted, listenDeletedPeer)
}

//startListenerClusterConfig is a wrapper that starts the listeners regarding Liqo configuration data.
func startListenerClusterConfig(i *app.Indicator) {
	i.Listen(client.ChanClusterName, listenClusterName)
}
