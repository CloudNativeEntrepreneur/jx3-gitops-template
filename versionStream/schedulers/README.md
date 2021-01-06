## Schedulers

These scheduler configuration files are used to configure the [Lighthouse](https://github.com/jenkins-x/lighthouse) configuration for different repositories.

You can associate a `Scheduler` name with a particular git repository group/owner/user or repository via the `scheduler` property in the `.jx/gitops/source-config.yaml` file.

That data merged with the contents of this folder to create the [Lighthouse](https://github.com/jenkins-x/lighthouse) configuration files via the [jx gitops schedule](https://github.com/jenkins-x/jx-gitops/blob/master/docs/cmd/jx-gitops_scheduler.md) step in pipelines.


### Default Schedulers

* [default](default.yaml) for use with classic Lighthouse or recent lighthouse with the jx engine
* [environment](environment.yaml) for Environments with classic Lighthouse or recent lighthouse with the jx engine
* [in-repo](in-repo.yaml) when using the tekton engine with Lighthouse when the triggers are inside the git repository in `.lighhouse/*/trigger.yaml`
* [jx-meta-pipeline](jx-meta-pipeline.yaml) when using the `jenkins-x.yml` approach and the `jx-meta-pipepeline` `Pipeline` is used to implement CI/CD