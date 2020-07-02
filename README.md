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
# Official Apache Pulsar Helm Chart

This is the officially supported Helm Chart for installing Apache Pulsar on Kubernetes.

Read [Deploying Pulsar on Kubernetes](http://pulsar.apache.org/docs/en/deploy-kubernetes/) for more details.

## Release Process

1. Bump the version in [charts/pulsar/Chart.yaml](https://github.com/apache/pulsar-helm-chart/blob/master/charts/pulsar/Chart.yaml#L24).

2. Send a pull request for reviews.

3. After the pull request is approved, merge it. The release workflow will be triggered automatically.
   - It creates a tag named `pulsar-<version>`.
   - Published the packaged helm chart to Github releases.
   - Update the `charts/index.yaml` in Pulsar website.

4. Trigger the Pulsar website build to make the release available under https://pulsar.apache.org/charts.
