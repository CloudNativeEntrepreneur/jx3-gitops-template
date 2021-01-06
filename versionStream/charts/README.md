## Charts

This directory tree contains default properties of helm charts if no version or namespace is specified in your `helmfile.yaml` file along with default values files.

### Defaults 

The file layout is `[repositoryPrefix]/chartName/defaults.yaml` with the YAML file containing a `version:` property and an optional default `namespace` property which is used if no namespace is specified in the `helmfile.yaml`

e.g.

* [jenkins-x](jenkins-x)/[tekton](jenkins-x/tekton)/[defaults.yaml](jenkins-x/tekton/defaults.yaml)

The mapping of repository prefixes to URLs is specified in the [repositories.yml](repositories.yml) file

### Values files

A chart folder can include a values file or values template:

* `[repositoryPrefix]/chartName/values.yaml` the `values.yaml` which should be added to the helm command via `--values` argument
* `[repositoryPrefix]/chartName/values.yaml.gotmpl` a go template which is rendered by `helmfile` into a `values.yaml` which will be added to the helm command via `--values` argument

e.g.

* [jenkins-x](jenkins-x)/[tekton](jenkins-x/tekton)/[values.yaml.gotmpl](jenkins-x/tekton/values.yaml.gotmpl)


