package client

//notifyBuffLength is the buffer length for the NotifyChannel channels of a cache.
const notifyBuffLength = 100

//NotifyChannel identifies a notification channel for a specific event.
type NotifyChannel int

//NotifyChannel identifiers.
const (
	//Notification channel id for an update of an available peer.
	ChanPeerAddedOrUpdated NotifyChannel = iota
	//Notification channel id for the removal of an available peer.
	ChanPeerDeleted
)

//notifyChannelNames contains all the registered NotifyChannel managed by the AgentController.
//It is used for init and testing purposes.
var notifyChannelNames = []NotifyChannel{
	ChanPeerAddedOrUpdated,
	ChanPeerDeleted,
}
