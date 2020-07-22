# Pulsar Helm Chart

- [Pulsar Helm Chart](#pulsar-helm-chart)
    - [Overview](#overview)
    - [Working with pulsar chart](#working-with-pulsar-chart)
      - [Chart url](#chart-url)
      - [Local development](#local-development)
    - [Steps to update the chart from apache repo](#steps-to-update-the-chart-from-apache-repo)

### Overview

This chart is a cloned version of [official apache helm chart](https://github.com/apache/pulsar-helm-chart).

Updating the chart should be avoided in favor of making changes in [original pulsar chart.](https://github.com/apache/pulsar-helm-chart)

Read [Deploying Pulsar on Kubernetes](http://pulsar.apache.org/docs/en/deploy-kubernetes/) for more details.

### Working with pulsar chart

Pulsar chart are automatically packaged and published by [HelmPipeline](https://github.optum.com/link/pipeline-library/tree/master/src/com/optum/link/pipeline/helm) at  https://repo1.uhc.com/artifactory/helm-virtual/

#### Chart url
https://repo1.uhc.com/artifactory/helm-virtual/

#### Local development

Use a one of the example values file i.e. `examples/values-one-node.yaml`

To install a chart using using example values:

```shell
helm upgrade pulsar --debug --install --create-namespace -f examples/values-one-node.yaml charts/pulsar
```

To execute a set of templates without installing them anywhere:

```shell
helm template <fake-release-name> <chart> -f values.local.yaml
```

To ensure that template syntax is valid and _well-formed_, please run:

```shell
helm lint <chart>
```

### Steps to update the chart from apache repo

- Clone this repo
- Add remote apache pulsar chart
- Set upstream of your branch to apache remote
- Pull and merge
- Switch back upstream to link remote
- Push

