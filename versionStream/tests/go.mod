module github.com/jenkins-x/jxr-versions

go 1.15

require (
	github.com/jenkins-x/jx-api/v4 v4.0.25
	github.com/jenkins-x/jx-helpers/v3 v3.0.90
	github.com/jenkins-x/jx-secret v0.1.10
	k8s.io/api v0.20.4
	k8s.io/apimachinery v0.20.4
)

replace (
	k8s.io/api => k8s.io/api v0.20.2
	k8s.io/apimachinery => k8s.io/apimachinery v0.20.2
	k8s.io/client-go => k8s.io/client-go v0.20.2
)
