package metrics

import (
	csvtag "github.com/artonge/go-csv-tag"
	"github.com/struCoder/pidusage"
	"math"
	"os"
	"path/filepath"
	"runtime"
	"sync"
	"time"
)

const (
	ResourcesExportFileName = "agent_resources.csv"
	TimeExportFileName      = "agent_time.csv"
)
const (
	MeasureIterations = 5
	MeasureStep       = 2 * time.Second
)

var (
	MTGetIndicator              int
	MTAgentController           int
	MTDiscoveryControllerAdd    int
	MTDiscoveryControllerUpdate int
	MTDiscoveryMenu             int
	MTOnReady                   int
)

const (
	MROnReadyStart       = "OnReadyStart"
	MROnReadyEnd         = "OnReadyEnd"
	MRPeerDiscovered     = "PeerDiscovered"
	MRPeeringEstablished = "PeeringEstablished"
)

type MetricResources struct {
	//row unique ID
	ID int `csv:"ID"`
	//code section where the measurement is taken
	Location string `csv:"CodeLocation"`
	//current number of discovered clusters.
	DiscoveredPeers int `csv:"DiscoveredPeers"`
	//cpu percentage used by the application. Values is first rounded to 3 decimal places It is stored as cpu% * 10E3.
	CPU uint64 `csv:"CPU"`
	//mem quota dedicated to heap (user space). Unit is MB.
	MemHeap uint64 `csv:"UserMemory"`
	//mem quota allocated by the OS. Unit is MB.
	MemOS uint64 `csv:"SystemMemory"`
}

type MetricTimer struct {
	ID int `csv:"ID"`
	//code section where the measurement is taken
	Tag string `csv:"Tag"`
	//current number of discovered clusters.
	DiscoveredPeers int `csv:"DiscoveredPeers"`
	//start time of measure
	StartTime time.Time
	//duration interval in ms
	Duration int64 `csv:"Elapsed"`
}

type MetricController struct {
	Pid       int
	IDCounter int
	sync.RWMutex
	Metrics        []MetricResources
	MetricsMap     map[int]*MetricTimer
	ExportFilePath string
	Enabled        bool
}

var DiscoveredPeers = &struct {
	Peers int
	sync.RWMutex
}{}

var MetricResourcesCtl = &MetricController{
	Pid:            os.Getpid(),
	Metrics:        []MetricResources{},
	ExportFilePath: filepath.Join(os.Getenv("HOME"), ResourcesExportFileName),
	Enabled:        true,
	//!pay attention MetricsMap is not initialized
}

var MetricTimerCtl = &MetricController{
	Pid:            os.Getpid(),
	MetricsMap:     map[int]*MetricTimer{},
	ExportFilePath: filepath.Join(os.Getenv("HOME"), TimeExportFileName),
	Enabled:        true,
}

func NewMetricTimer(location string) (id int) {
	if MetricTimerCtl.Enabled {
		MetricTimerCtl.Lock()
		defer MetricTimerCtl.Unlock()
		id = MetricTimerCtl.IDCounter
		MetricTimerCtl.IDCounter++
		DiscoveredPeers.RLock()
		defer DiscoveredPeers.RUnlock()
		MetricTimerCtl.MetricsMap[id] = &MetricTimer{
			ID:              id,
			Tag:             location,
			DiscoveredPeers: DiscoveredPeers.Peers,
			StartTime:       time.Now(),
		}
	}
	return
}

func StopMetricTimer(id int, stop time.Time) {
	if MetricTimerCtl.Enabled {
		MetricTimerCtl.Lock()
		defer MetricTimerCtl.Unlock()
		m := MetricTimerCtl.MetricsMap[id]
		m.Duration = stop.Sub(m.StartTime).Milliseconds()
	}
}

func DumpMetricTimers() {
	if MetricTimerCtl.Enabled {
		MetricTimerCtl.RLock()
		defer MetricTimerCtl.RUnlock()
		var container []MetricTimer
		for _, v := range MetricTimerCtl.MetricsMap {
			container = append(container, *v)
		}
		_ = csvtag.DumpToFile(container, MetricTimerCtl.ExportFilePath)
	}
}

func NewMetricResources(location string) {
	if MetricResourcesCtl.Enabled {
		var m runtime.MemStats
		runtime.ReadMemStats(&m)
		sysInfo, _ := pidusage.GetStat(MetricResourcesCtl.Pid)
		DiscoveredPeers.RLock()
		defer DiscoveredPeers.RUnlock()
		metric := MetricResources{
			Location:        location,
			DiscoveredPeers: DiscoveredPeers.Peers,
		}
		metric.CPU = uint64(math.Round(sysInfo.CPU * 1000))
		metric.MemHeap = m.Alloc / 1048576 //convert byte to MByte
		metric.MemOS = m.Sys / 1048576
		MetricResourcesCtl.Lock()
		defer MetricResourcesCtl.Unlock()
		metric.ID = MetricResourcesCtl.IDCounter
		MetricResourcesCtl.IDCounter++
		MetricResourcesCtl.Metrics = append(MetricResourcesCtl.Metrics, metric)
	}
}

func DumpMetricResources() {
	if MetricResourcesCtl.Enabled {
		_ = csvtag.DumpToFile(MetricResourcesCtl.Metrics, MetricResourcesCtl.ExportFilePath)
	}
}
