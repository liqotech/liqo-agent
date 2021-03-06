package app_indicator

import (
	"github.com/liqotech/liqo-agent/internal/tray-agent/agent/client"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestIndicator_NotificationSetLevel(t *testing.T) {
	UseMockedGuiProvider()
	client.UseMockedAgentController()
	DestroyMockedIndicator()
	client.DestroyMockedAgentController()
	i := GetIndicator()
	i.NotificationSetLevel(NotifyLevelOff)
	assert.Equalf(t, NotifyLevelOff, i.config.notifyLevel, "fail on setting "+
		"NotifyLevelOff")
	i.NotificationSetLevel(NotifyLevelMin)
	assert.Equalf(t, NotifyLevelMin, i.config.notifyLevel, "fail on setting "+
		"NotifyLevelMin")
	i.NotificationSetLevel(NotifyLevelMax)
	assert.Equalf(t, NotifyLevelMax, i.config.notifyLevel, "fail on setting "+
		"NotifyLevelMax")
	i.NotificationSetLevel(-1)
	assert.Equalf(t, NotifyLevelMax, i.config.notifyLevel, "wrong argument accepted")
}

func TestIndicator_Notify(t *testing.T) {
	UseMockedGuiProvider()
	client.UseMockedAgentController()
	DestroyMockedIndicator()
	client.DestroyMockedAgentController()
	i := GetIndicator()
	// test if any change happen when notifications are turned off
	i.config.notifyLevel = NotifyLevelOff
	i.Notify("", "", NotifyIconNil, IconLiqoOrange)
	assert.Equal(t, IconLiqoMain, i.icon, "notify level off")
	// test if indicator icon change with a valid icon with NotifyLevelMin
	i.config.notifyLevel = NotifyLevelMin
	i.Notify("", "", NotifyIconError, IconLiqoOrange)
	assert.Equal(t, IconLiqoOrange, i.icon, "notify level min + valid icon does not change")
	// test if indicator icon does not change with an invalid icon with NotifyLevelMin
	i.Notify("", "", NotifyIconWarning, IconLiqoNil)
	assert.Equal(t, IconLiqoOrange, i.icon, "notify level min + invalid icon changes")
	// test if indicator icon change with a valid icon with NotifyLevelMax
	i.config.notifyLevel = NotifyLevelMax
	i.Notify("", "", NotifyIconDefault, IconLiqoNoConn)
	assert.Equal(t, IconLiqoNoConn, i.icon, "notify level max + valid icon does not change")
	// test if indicator icon does not change with an invalid icon with NotifyLevelMin
	i.Notify("", "", NotifyIconWhite, IconLiqoNil)
	assert.Equal(t, IconLiqoNoConn, i.icon, "notify level max + invalid icon changes")
	// test if indicator icon does not change with an invalid NotifyLevel
	i.Notify("", "", NotifyIconNil, -1)
	assert.Equal(t, IconLiqoNoConn, i.icon, "notify level max + invalid value changes")
}

// test the set of pre-configured Notify*() methods
func TestIndicator_NotifyFunctions(t *testing.T) {
	UseMockedGuiProvider()
	client.UseMockedAgentController()
	DestroyMockedIndicator()
	client.DestroyMockedAgentController()
	i := GetIndicator()
	//test if Indicator icon correctly changes accordingly to each default Notify*() internal config
	i.NotifyNoConnection()
	assert.Equal(t, IconLiqoWarning, i.icon, "NotifyNoConnection: indicator icon not correctly set")
}
