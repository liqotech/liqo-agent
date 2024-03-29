module github.com/liqotech/liqo-agent

go 1.14

replace k8s.io/legacy-cloud-providers => k8s.io/legacy-cloud-providers v0.18.6

replace k8s.io/cloud-provider => k8s.io/cloud-provider v0.18.6

replace k8s.io/cli-runtime => k8s.io/cli-runtime v0.18.6

replace k8s.io/apiserver => k8s.io/apiserver v0.18.6

replace k8s.io/csi-translation-lib => k8s.io/csi-translation-lib v0.18.6

replace k8s.io/cri-api => k8s.io/cri-api v0.18.6

replace k8s.io/kube-aggregator => k8s.io/kube-aggregator v0.18.6

replace k8s.io/kubelet => k8s.io/kubelet v0.18.6

replace k8s.io/kube-controller-manager => k8s.io/kube-controller-manager v0.18.6

replace k8s.io/apimachinery => k8s.io/apimachinery v0.18.6

replace k8s.io/api => k8s.io/api v0.18.6

replace k8s.io/cluster-bootstrap => k8s.io/cluster-bootstrap v0.18.6

replace k8s.io/kube-proxy => k8s.io/kube-proxy v0.18.6

replace k8s.io/component-base => k8s.io/component-base v0.18.6

replace k8s.io/kube-scheduler => k8s.io/kube-scheduler v0.18.6

replace k8s.io/apiextensions-apiserver => k8s.io/apiextensions-apiserver v0.18.6

replace k8s.io/metrics => k8s.io/metrics v0.18.6

replace k8s.io/sample-apiserver => k8s.io/sample-apiserver v0.18.6

replace k8s.io/code-generator => k8s.io/code-generator v0.18.6

replace k8s.io/client-go => k8s.io/client-go v0.18.6

replace k8s.io/kubectl => k8s.io/kubectl v0.18.6

replace k8s.io/node-api => k8s.io/node-api v0.18.6

replace k8s.io/sample-cli-plugin => k8s.io/sample-cli-plugin v0.18.6

replace k8s.io/sample-controller => k8s.io/sample-controller v0.18.6

replace github.com/grandcat/zeroconf => github.com/liqotech/zeroconf v1.0.1-0.20201020081245-6384f3f21ffb

require (
	github.com/agrison/go-commons-lang v0.0.0-20200208220349-58e9fcb95174
	github.com/atotto/clipboard v0.1.4
	github.com/gen2brain/beeep v0.0.0-20200526185328-e9c15c258e28
	github.com/gen2brain/dlgs v0.0.0-20210406143744-f512297a108e
	github.com/getlantern/systray v1.1.0
	github.com/liqotech/liqo v0.0.0-20210420132036-80a671bd49d9
	github.com/oleiade/lane v1.0.1
	github.com/ozgio/strutil v0.3.0
	github.com/skratchdot/open-golang v0.0.0-20200116055534-eef842397966
	github.com/stretchr/testify v1.7.0
	gopkg.in/yaml.v2 v2.4.0
	k8s.io/api v0.20.1
	k8s.io/apimachinery v0.20.1
	k8s.io/client-go v12.0.0+incompatible
)
