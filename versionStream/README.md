## Jenkins X 3.x Version Stream

This repository contains the versions of helm charts, images, git repositories, command line tools (packages) and other resources.

See the documentation on [version streams](https://jenkins-x.io/about/concepts/version-stream/).

The main directories are:

* [charts](charts) for helm chart version and configuration files
* [git](git) for git repositories
* [git-operator](git-operator) the boot [Job](git-operator/job.yaml) definition for booting a cluster
* [images](docker) for container images
* [packages](packages) for packages (local command line tools)
* [schedulers](schedulers) contains the default scheduler files for generating [Lighthouse](https://github.com/jenkins-x/lighthouse) configuration
* [secrets](secrets) the default secret mapping files for defining how to map External Secrets to the underlying secret storage (e.g. Vault / GSM / ASM)
* [src](src) the common source code for the boot job and the [Makefile](src/Makefile.mk)
