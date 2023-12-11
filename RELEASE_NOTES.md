<!--

    Licensed to the Apache Software Foundation (ASF) under one
    or more contributor license agreements.  See the NOTICE file
    distributed with this work for additional information
    regarding copyright ownership.  The ASF licenses this file
    to you under the Apache License, Version 2.0 (the
    "License"); you may not use this file except in compliance
    with the License.  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing,
    software distributed under the License is distributed on an
    "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
    KIND, either express or implied.  See the License for the
    specific language governing permissions and limitations
    under the License.

-->
# Apache Pulsar Helm Chart Release Notes

## 3.0.0

This Apache Pulsar Helm Chart release contains several important new features, bug fixes, and some potential breaking changes. Most importantly, it ships with Apache Pulsar 2.10.2, by default.

## Breaking Changes

* Switch from custom deployment of Prometheus and Grafana to using the [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts). This change includes enabling `PodMonitors` by default for the Broker, Bookkeeper, Zookeeper, Autorecovery, and Proxy pods, as well as deploying the related CRDs by default. If this will be a problem, here is documentation to [disable](https://github.com/apache/pulsar-helm-chart#disabling-kube-prometheus-stack-crds) the CRD deployment. Additionally, the Grafana Dashboards that were previously deployed will no longer ship with this Helm Chart. Here is [documentation](https://github.com/apache/pulsar-helm-chart#grafana-dashboards) on available alternatives. Here is the related PR https://github.com/apache/pulsar-helm-chart/pull/299.

## Upgrade considerations

* When upgrading from any previous version of the helm chart, there are a few things to consider. First, this is the first release of the Helm Chart that packages a 2.10 docker image as the default version of Apache Pulsar. Notably, that docker image is run as a non root user, by default. As a result, you may have issues with Zookeeper and Bookkeeper file system permissions. If so, you may need to use the following in your initial values file. See https://github.com/apache/pulsar-helm-chart#upgrading-to-apache-pulsar-2100-and-above-or-helm-chart-version-300-and-above for more instructions.
    ```yaml
      securityContext:
        fsGroup: 0
        fsGroupChangePolicy: "Always"
    ```
* When upgrading to the [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts), the helm chart will not install the CRDs by default. You can install those following these instructions: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack#from-40x-to-41x.

## What's Changed
* Bump Apache Pulsar 2.10.2 by @Jason918 in https://github.com/apache/pulsar-helm-chart/pull/310
* Replace monitoring solution with kube-prometheus-stack dependency by @michaeljmarshall in https://github.com/apache/pulsar-helm-chart/pull/299

## Enhancements
* Add nodeSelector to cluster initialize pod by @ThelonKarrde in https://github.com/apache/pulsar-helm-chart/pull/284
* Alphabetically sort list of super users by @arnarg in https://github.com/apache/pulsar-helm-chart/pull/291
* Use appVersion as default tag for Pulsar images by @lhotari in https://github.com/apache/pulsar-helm-chart/pull/200
* Support mechanism to provide external zookeeper-server list to build global/configuration zookeeper by @rdhabalia in https://github.com/apache/pulsar-helm-chart/pull/269
* Update how to configure external zookeeper servers by @michaeljmarshall in https://github.com/apache/pulsar-helm-chart/pull/308
* Allow to use selectors with volumeClaimTemplates by @claudio-vellage in https://github.com/apache/pulsar-helm-chart/pull/286
* Allow specifying the nodeSelector for the init jobs by @elangelo in https://github.com/apache/pulsar-helm-chart/pull/225
* Added pdb version detection by @yuweisung in https://github.com/apache/pulsar-helm-chart/pull/260
* Allow bk cluster init pod to restart on failure by @michaeljmarshall in https://github.com/apache/pulsar-helm-chart/pull/303

## Bug Fixes
* Remove '|| yes' in bk cluster init script by @michaeljmarshall in https://github.com/apache/pulsar-helm-chart/pull/305
* Fix bookkeeper metadata init when specifying metadataPrefix by @michaeljmarshall in https://github.com/apache/pulsar-helm-chart/pull/316
* feat(certs): use actual v1 spec for certs by @smazurov in https://github.com/apache/pulsar-helm-chart/pull/233

## Build and CI Changes
* Only send notifications to commits@ ML by @michaeljmarshall in https://github.com/apache/pulsar-helm-chart/pull/302
* Remove GitHub Action Workflows that release the chart by @michaeljmarshall in https://github.com/apache/pulsar-helm-chart/pull/300
* Use cert-manager to generate certs for tests by @michaeljmarshall in https://github.com/apache/pulsar-helm-chart/pull/306
* Upgrade to Cert Manager 1.7.3 by @michaeljmarshall in https://github.com/apache/pulsar-helm-chart/pull/307
* Fix monitoring configuration broken by #299 by @michaeljmarshall in https://github.com/apache/pulsar-helm-chart/pull/313
* Replace handmade lint script with official action  by @tisonkun in https://github.com/apache/pulsar-helm-chart/pull/292
* [test] Add a consumer to the helm tests by @michaeljmarshall in https://github.com/apache/pulsar-helm-chart/pull/312
* Fix CI by modifying Chart.yaml and updating ct lint command by @michaeljmarshall in https://github.com/apache/pulsar-helm-chart/pull/315
* Do not require version bump by @michaeljmarshall in https://github.com/apache/pulsar-helm-chart/pull/314


## Release Update

The Apache Pulsar Helm Chart's release process has changed from an automated process to a manual one, in order to align with the Apache Software Foundation's requirements for voting on releases. As a result, you can expect releases to be hosted at https://downloads.apache.org/pulsar/helm-chart/. Please see the [RELEASE.md](./RELEASE.md) for the new release process.

## New Contributors
Thank you to all of our new contributors!

* @ThelonKarrde made their first contribution in https://github.com/apache/pulsar-helm-chart/pull/284
* @arnarg made their first contribution in https://github.com/apache/pulsar-helm-chart/pull/291
* @smazurov made their first contribution in https://github.com/apache/pulsar-helm-chart/pull/233
* @rdhabalia made their first contribution in https://github.com/apache/pulsar-helm-chart/pull/269
* @yuweisung made their first contribution in https://github.com/apache/pulsar-helm-chart/pull/260
* @tisonkun made their first contribution in https://github.com/apache/pulsar-helm-chart/pull/292
* @Jason918 made their first contribution in https://github.com/apache/pulsar-helm-chart/pull/310
* @elangelo made their first contribution in https://github.com/apache/pulsar-helm-chart/pull/225
* @claudio-vellage made their first contribution in https://github.com/apache/pulsar-helm-chart/pull/286

**Full Changelog**: https://github.com/apache/pulsar-helm-chart/compare/pulsar-2.9.4...pulsar-3.0.0