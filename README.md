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

# Apache Pulsar Helm Chart [![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/apache/pulsar-helm-chart)

This project provides Helm Charts for installing Apache Pulsar on Kubernetes.

Read [Deploying Pulsar on Kubernetes](http://pulsar.apache.org/docs/deploy-kubernetes/) for more details.

> :warning: This helm chart is updated outside of the regular Pulsar release cycle and might lag behind a bit. It only supports basic Kubernetes features now. Currently, it can be used as no more than a template and starting point for a Kubernetes deployment. In many cases, it would require some customizations.

## Important Security Advisory for Helm Chart Usage

### Notice of Default Configuration

This Helm chart's default configuration DOES NOT meet production security requirements.
Users MUST review and customize security settings for their specific environment.

IMPORTANT: This Helm chart provides a starting point for Pulsar deployments but requires
significant security customization before use in production environments. We strongly
recommend implementing:

1. Authentication and authorization for all components
2. TLS encryption for all communication channels
3. Proper network isolation and access controls
4. Regular security updates and vulnerability assessments

As an open source project, we welcome contributions to improve security features.
Please consider submitting pull requests to address security gaps or enhance
existing security implementations.

### Pulsar Proxy Security Considerations

As per the [Pulsar Proxy documentation](https://pulsar.apache.org/docs/3.1.x/administration-proxy/), it is explicitly stated that the Pulsar proxy is not designed for exposure to the public internet. The design assumes that deployments will be protected by network perimeter security measures. It is crucial to understand that relying solely on the default configuration can expose your deployment to significant security vulnerabilities.

### External Access Recommendations

If you need to expose the Pulsar Proxy outside the cluster:

1. **USE INTERNAL LOAD BALANCERS ONLY**
   - Set type to LoadBalancer only in secured environments with proper network controls
   - Add cloud provider-specific annotations for internal load balancers:
     - Kubernetes documentation about internal load balancers:
        - [Internal load balancer](https://kubernetes.io/docs/concepts/services-networking/service/#internal-load-balancer)
     - See cloud provider documentation:
       - AWS / EKS: [AWS Load Balancer Controller / Service Annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/service/annotations/)
       - Azure / AKS: [Use an internal load balancer with Azure Kubernetes Service (AKS)](https://learn.microsoft.com/en-us/azure/aks/internal-lb)
       - GCP / GKE: [LoadBalancer service parameters](https://cloud.google.com/kubernetes-engine/docs/concepts/service-load-balancer-parameters)
     - Examples (verify correctness for your environment):
       - AWS / EKS:  `service.beta.kubernetes.io/aws-load-balancer-internal: "true"`
       - Azure / AKS: `service.beta.kubernetes.io/azure-load-balancer-internal: "true"`
       - GCP / GKE:   `networking.gke.io/load-balancer-type: "Internal"`

2. **IMPLEMENT AUTHENTICATION AND AUTHORIZATION**
   - Configure all clients to authenticate properly
   - Set up appropriate authorization policies

3. **USE TLS FOR ALL CONNECTIONS**
   - Enable TLS for client-to-proxy connections
   - Enable TLS for proxy-to-broker connections
   - Enable TLS for all internal cluster communications
   - Note: TLS alone is NOT sufficient as a security solution. Even with TLS enabled, clusters exposed to untrusted networks remain vulnerable to denial-of-service attacks, authentication bypass attempts, and protocol-level exploits.

4. **NETWORK SECURITY**
   - Use private networks (VPCs)
   - Configure firewalls, security groups, and IP restrictions

5. **CLIENT IP ADDRESS BASED ACCESS RESTRICTIONS**

   - When using a LoadBalancer service type, restrict access to specific IP ranges by configuring `proxy.service.loadBalancerSourceRanges` in your values.yaml:
     ```yaml
     proxy:
       service:
         loadBalancerSourceRanges:
           - 10.0.0.0/8     # Private network range
           - 172.16.0.0/12  # Private network range
           - 192.168.0.0/16 # Private network range
     ```
   - This feature:
     - Provides an additional defense layer by filtering traffic at the load balancer level
     - Only allows connections from specified CIDR blocks
     - Works only with LoadBalancer service type and when your cloud provider supports the `loadBalancerSourceRanges` parameter
   - Important: This should be implemented alongside other security measures (internal load balancer, authentication, TLS, network policies) as part of a defense-in-depth strategy,
     not as a standalone security solution

### Alternative for External Access

As an alternative method for external access, Pulsar has support for [SNI proxy routing](https://pulsar.apache.org/docs/next/concepts-proxy-sni-routing/). SNI Proxy routing is supported with proxy servers such as Apache Traffic Server, HAProxy and Nginx.

Note: This option isn't currently implemented in the Apache Pulsar Helm chart.

**IMPORTANT**: Pulsar binary protocol cannot be exposed outside of the Kubernetes cluster using Kubernetes Ingress. Kubernetes Ingress works for the Admin REST API and topic lookups, but clients would be connecting to the advertised listener addresses returned by the brokers and it would only work when clients can connect directly to brokers. This is not a supported secure option for exposing Pulsar to untrusted networks.

### General Recommendations

- **Network Perimeter Security:** It is imperative to implement robust network perimeter security to safeguard your deployment. The absence of such security measures can lead to unauthorized access and potential data breaches.
- **Restricted Access:** For environments where security is less critical, such as certain development or testing scenarios, the use of `loadBalancerSourceRanges` may be employed to restrict access to specified IP addresses or ranges. This, however, should not be considered a substitute for comprehensive security measures in production environments.

### User Responsibility

The user assumes full responsibility for the security and integrity of their deployment. This includes, but is not limited to, the proper configuration of security features and adherence to best practices for securing network access. The providers of this Helm chart disclaim all warranties, whether express or implied, including any warranties of merchantability, fitness for a particular purpose, and non-infringement of third-party rights.

### No Security Guarantees

The providers of this Helm chart make no guarantees regarding the security of the chart under any circumstances. It is the user's responsibility to ensure that their deployment is secure and complies with all relevant security standards and regulations.

By using this Helm chart, the user acknowledges the risks associated with its default configuration and the necessity for proper security customization. The user further agrees that the providers of the Helm chart shall not be liable for any security breaches or incidents resulting from the use of the chart.

## Features

This Helm Chart includes all the components of Apache Pulsar for a complete experience.

- [x] Pulsar core components:
    - [x] ZooKeeper
    - [x] Bookies
    - [x] Brokers
    - [x] Functions
    - [x] Proxies
- [x] Management & monitoring components:
    - [x] Dekaf UI
    - [x] Pulsar Manager
    - [x] Optional PodMonitors for each component (enabled by default)
    - [x] [victoria-metrics-k8s-stack](hhttps://github.com/VictoriaMetrics/helm-charts/tree/master/charts/victoria-metrics-k8s-stack) (as of 4.0.0)

It includes support for:

- [x] Security
    - [x] Automatically provisioned TLS certs, using [Jetstack](https://www.jetstack.io/)'s [cert-manager](https://cert-manager.io/docs/)
        - [x] self-signed
        - [x] [Let's Encrypt](https://letsencrypt.org/)
    - [x] TLS Encryption
        - [x] Proxy
        - [x] Broker
        - [x] Toolset
        - [x] Bookie
        - [x] ZooKeeper (requires the `AdditionalCertificateOutputFormats=true` feature gate to be enabled in the cert-manager deployment when using cert-manager versions below 1.15.0)
    - [x] Authentication
        - [x] JWT
        - [x] OpenID
        - [ ] Mutal TLS
        - [ ] Kerberos
    - [x] Authorization
    - [x] Non-root broker, bookkeeper, proxy, and zookeeper containers (version 2.10.0 and above)
- [x] Storage
    - [x] Non-persistence storage
    - [x] Persistence Volume
    - [x] Local Persistent Volumes
    - [x] Tiered Storage
- [x] Functions
    - [x] Kubernetes Runtime
    - [x] Process Runtime
    - [x] Thread Runtime
- [x] Operations
    - [x] Independent Image Versions for all components, enabling controlled upgrades

## Requirements

In order to use this chart to deploy Apache Pulsar on Kubernetes, the followings are required.

1. kubectl 1.25 or higher, compatible with your cluster ([+/- 1 minor release from your cluster](https://kubernetes.io/docs/tasks/tools/install-kubectl/#before-you-begin))
2. Helm v3 (3.12.0 or higher)
3. A Kubernetes cluster, version 1.25 or higher.

## Environment setup

Before proceeding to deploying Pulsar, you need to prepare your environment.

### Tools

`helm` and `kubectl` need to be [installed on your computer](https://pulsar.apache.org/docs/helm-tools/).

## Add to local Helm repository

To add this chart to your local Helm repository:

```bash
helm repo add apachepulsar https://pulsar.apache.org/charts
helm repo update
```

## Kubernetes cluster preparation

You need a Kubernetes cluster whose version is 1.25 or higher in order to use this chart, due to the usage of certain Kubernetes features.

We provide some instructions to guide you through the preparation: http://pulsar.apache.org/docs/helm-prepare/

## Deploy Pulsar to Kubernetes

1. Configure your values file. The best way to know which values are available is to read the [values.yaml](./charts/pulsar/values.yaml)
   (or run `helm show values apachepulsar/pulsar`).
   A best practice is to start with an empty values file and only set the keys that differ from the default configuration.
   Ready-made example value files for common scenarios (single-node, TLS, JWT, Oxia, and more) are in [`examples/`](examples/README.md).

   Anti-affinity rules for Zookeeper and Bookie components require at least one node per replica. For Kubernetes clusters with less than 3 nodes,
   you must disable this feature by adding this to your initial values.yaml file:

    ```yaml
    affinity:
      anti_affinity: false
    ```

2. Install the chart:

    ```bash
    helm install -n <namespace> --create-namespace <release-name> -f your-values.yaml apachepulsar/pulsar
    ```

3. Observe the deployment progress

    Watching events to view progress of deployment:

    ```shell
    kubectl get -n <namespace> events -o wide --watch
    ```

    Watching state of deployed Kubernetes objects, updated every 2 seconds:

    ```shell
    watch kubectl get -n <namespace> all
    ```

    Waiting until Pulsar Proxy is available:

    ```shell
    kubectl wait --timeout=600s --for=condition=ready pod -n <namespace> -l component=proxy
    ```

    Watching state with k9s (https://k9scli.io/topics/install/):

    ```shell
    k9s -n <namespace>
    ```

4. Access the Pulsar cluster

    The default values will create a `ClusterIP` for the proxy you can use to interact with the cluster. To find the IP address of proxy use:

    ```bash
    kubectl get service -n <k8s-namespace>
    ```

For more information, please follow our detailed
[quick start guide](https://pulsar.apache.org/docs/getting-started-helm/).

## Customize the deployment

We provide a [detailed guideline](https://pulsar.apache.org/docs/helm-deploy/) for you to customize
the Helm Chart for a production-ready deployment.

You can also check out the example values files for different deployments. See
[`examples/README.md`](examples/README.md) for the full annotated list. A few
common ones:

- [Deploy a minimal single-node cluster](examples/values-one-node.yaml)
- [Deploy ZooKeeper only as a configuration store](examples/values-cs.yaml)
- [Deploy a Pulsar cluster with an external configuration store](examples/values-local-cluster.yaml)
- [Deploy a Pulsar cluster with local persistent volume](examples/values-local-pv.yaml)
- [Deploy a Pulsar cluster to Minikube](examples/values-minikube.yaml)
- [Deploy a Pulsar cluster with no persistence](examples/values-no-persistence.yaml)
- [Deploy a Pulsar cluster with TLS encryption (self-signed)](examples/values-tls-selfsigned.yaml)
- [Deploy a Pulsar cluster with TLS encryption (CA issuer)](examples/values-tls-ca.yaml)
- [Deploy a Pulsar cluster with JWT authentication using symmetric key](examples/values-jwt-symmetric.yaml)
- [Deploy a Pulsar cluster with JWT authentication using asymmetric key](examples/values-jwt-asymmetric.yaml)

These example files are small, focused overrides meant to be combined: pass `-f`
multiple times (later files win), or use the [`merge-values.sh`](examples/merge-values.sh)
helper to merge several into a single file. See [`examples/README.md`](examples/README.md)
for the full list and usage details.

## Disabling victoria-metrics-k8s-stack components

In order to disable the victoria-metrics-k8s-stack, you can add the following to your `values.yaml`.
Victoria Metrics components can also be disabled and enabled individually if you only need specific monitoring features.

```yaml
# disable VictoriaMetrics and related components
victoria-metrics-k8s-stack:
  enabled: false
  victoria-metrics-operator:
    enabled: false
  vmsingle:
    enabled: false
  vmagent:
    enabled: false
  kube-state-metrics:
    enabled: false
  prometheus-node-exporter:
    enabled: false
  grafana:
    enabled: false
```

Additionally, you'll need to set each component's `podMonitor` property to `false`.

```yaml
# disable pod monitors
autorecovery:
  podMonitor:
    enabled: false
bookkeeper:
  podMonitor:
    enabled: false
oxia:
  server:
    podMonitor:
      enabled: false
  coordinator:
    podMonitor:
      enabled: false
broker:
  podMonitor:
    enabled: false
proxy:
  podMonitor:
    enabled: false
zookeeper:
  podMonitor:
    enabled: false
```

This is shown in some [examples/values-disable-monitoring.yaml](examples/values-disable-monitoring.yaml).

## Dekaf UI

[Dekaf](https://github.com/visortelle/dekaf) is a new open-source UI for Apache Pulsar.

> :warning: At this moment Dekaf doesn't have built-in authentication. In order to prevent unwanted access, it relies on authentication on the Pulsar broker side.
> If your Pulsar instance stores sensitive data, make sure that:
> - You have configured authentication on the Pulsar side
> - Dekaf isn't accessible from the Internet
> - Only authorized persons have access to you Kubernetes namespace
>
> Improvements in this area are planned to be implemented later.

To enable the Dekaf component:

- Set the `components.dekaf` property to `true` in the Helm release `values.yaml` file
  (several [example values files](examples/README.md) already enable it).
- Run the following command to make Dekaf service accessible on your local machine.

```
kubectl port-forward svc/$(kubectl get svc -l component=dekaf -o jsonpath='{.items[0].metadata.name}') 8090:8090
```

- Open <http://localhost:8090> in browser.

## Pulsar Manager

> :warning: Pulsar Manager has been poorly maintained for a long time. Consider the Dekaf UI instead.

The Pulsar Manager can be deployed alongside the pulsar cluster instance.
Depending on the given settings it uses an existing Secret within the given namespace or creates a new one, with random
passwords for both, the UI and the internal database.

To forward the UI use (assumes you did not change the namespace):

```
kubectl port-forward $(kubectl get pods -l component=pulsar-manager -o jsonpath='{.items[0].metadata.name}') 9527:9527
```

And then opening the browser to http://localhost:9527

The default user is `pulsar` and you can find out the password with this command

```
kubectl get secret -l component=pulsar-manager -o=jsonpath="{.items[0].data.UI_PASSWORD}" | base64 --decode
```

## Grafana Dashboards

The Apache Pulsar Helm Chart uses the `victoria-metrics-k8s-stack` Helm Chart to deploy Grafana.

There are several ways to configure Grafana dashboards. The default [`values.yaml`](charts/pulsar/values.yaml) comes with examples of Pulsar dashboards which get downloaded from the Apache-2.0 licensed [lhotari/pulsar-grafana-dashboards OSS project](https://github.com/lhotari/pulsar-grafana-dashboards) by URL.

Dashboards can be configured in [`values.yaml`](charts/pulsar/values.yaml) or by adding `ConfigMap` items with the label `grafana_dashboard: "1"`.
In [`values.yaml`](charts/pulsar/values.yaml), it's possible to include dashboards by URL or by grafana.com dashboard id (`gnetId` and `revision`).
Please see the [Grafana Helm chart documentation for importing dashboards](https://github.com/grafana/helm-charts/blob/main/charts/grafana/README.md#import-dashboards).

You can connect to Grafana by forwarding port 3000
```
kubectl port-forward $(kubectl get pods -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}') 3000:3000
```
And then opening the browser to http://localhost:3000 . The default user is `admin`.

You can find out the password with this command
```
kubectl get secret -l app.kubernetes.io/name=grafana -o=jsonpath="{.items[0].data.admin-password}" | base64 --decode
```

### Pulsar Grafana Dashboards

* The `apache/pulsar` GitHub repo contains some Grafana dashboards [here](https://github.com/apache/pulsar/tree/master/grafana).
* StreamNative provides Grafana Dashboards for Apache Pulsar in this [GitHub repository](https://github.com/streamnative/apache-pulsar-grafana-dashboard).
* DataStax provides Grafana Dashboards for Apache Pulsar in this [GitHub repository](https://github.com/datastax/pulsar-helm-chart/tree/master/helm-chart-sources/pulsar/grafana-dashboards).

Note: if you have third party dashboards that you would like included in this list, please open a pull request.

## Upgrading

Once your Pulsar Chart is installed, configuration changes and chart
updates should be done using `helm upgrade`.

```bash
helm repo add apachepulsar https://pulsar.apache.org/charts
helm repo update
# If you are using the provided victoria-metrics-k8s-stack for monitoring, this installs or upgrades the required CRDs
./scripts/victoria-metrics-k8s-stack/upgrade_vm_operator_crds.sh
# get the existing values.yaml used for the most recent deployment
helm get values -n <namespace> <pulsar-release-name> > values.yaml
# upgrade the deployment
helm upgrade -n <namespace> -f values.yaml <pulsar-release-name> apachepulsar/pulsar
```

For more detailed information, see our [Upgrading](http://pulsar.apache.org/docs/helm-upgrade/) guide.

## Upgrading to Helm chart version 4.6.0

### ZooKeeper and Broker Services split into ClusterIP + headless

> **Note:** Upgrading existing installs may cause a brief service disruption. The StatefulSet's `serviceName` is immutable, so the ZooKeeper and Broker StatefulSets are re-created during the upgrade (see [Upgrading: pre-upgrade cleanup Job](#upgrading-pre-upgrade-cleanup-job) below).

PRs [#649](https://github.com/apache/pulsar-helm-chart/pull/649) and [#650](https://github.com/apache/pulsar-helm-chart/pull/650) replace the single Service that fronted each of the ZooKeeper and Broker StatefulSets with two:

- a regular **ClusterIP Service** (`<release>-zookeeper`, `<release>-broker`) — used by clients; only routes to ready pods. The default for the main Broker service has changed from headless to ClusterIP.
- a **headless Service** (`*-headless`, `clusterIP: None`, `publishNotReadyAddresses: true`) — used as the StatefulSet `serviceName` for stable per-pod DNS.

#### Why

**ZooKeeper.** The previous Service had `publishNotReadyAddresses: true`, so brokers and bookies could be routed to ZK pods that were still starting or unhealthy. Splitting into a ready-only ClusterIP Service for clients and a headless Service for per-pod DNS fixes that.

**Brokers** (issue [#437](https://github.com/apache/pulsar-helm-chart/issues/437)). A broker registers itself in ZooKeeper using its **per-pod** DNS name; other brokers and clients then resolve that name to reach it. The previous headless Service did **not** set `publishNotReadyAddresses`, so the per-pod name only became resolvable after the pod's readiness probe passed (plus DNS-cache TTL). Meanwhile the load manager could already have assigned namespace bundles to the new broker, causing a brief disruption on those topics. The new headless Service sets `publishNotReadyAddresses: true`, so the per-pod name resolves immediately. Two further benefits:

- Client lookups now go through a regular ClusterIP Service that returns a single IP. The previous headless Service returned one A record per broker, which can exceed the 512-byte UDP DNS limit in larger clusters. Some DNS clients cannot handle this due to lack of TCP fallback for DNS (for example Alpine <3.18).
- StatefulSets require a headless Service for pod identity, so the headless Service can only be paired with — not replaced by — a ClusterIP Service.

#### Upgrading: pre-upgrade cleanup Job

Because `serviceName` is immutable, an in-place upgrade from a pre-4.6.0 chart would fail. The chart ships a **`pre-upgrade` Job** per component that uses `kubectl` (image `images.kubectl`, default `alpine/k8s`) to delete the old StatefulSet with `--cascade=orphan`. Pods (and ZooKeeper on-disk data) are preserved and keep running until the new StatefulSet rolls them, but a brief disruption around the cutover is possible. The Job reads the existing chart label and only acts when the prior version is < 4.6.0; disable with `zookeeper.statefulsetUpgrade.enabled=false` or `broker.statefulsetUpgrade.enabled=false` to manage the migration manually.

> **GitOps users (ArgoCD, Flux, Pulumi, etc.):** the cleanup relies on Helm's `pre-upgrade` hook lifecycle, which isn't always honored by GitOps tooling that renders the chart and applies the manifests directly. Verify that your tool runs `helm.sh/hook: pre-upgrade` Jobs before the rest of the release — or disable the hook flags above and handle the StatefulSet deletion (with `--cascade=orphan`) as part of your migration — before upgrading to 4.6.0.

#### TLS

The hostnames of the broker and ZooKeeper pods have changed, and certificates now include the new `*-headless` DNS names as SANs. After cert-manager reissues them, do a rolling restart of ZooKeeper and brokers so the running pods pick up matching certificates.

### In-chart JWT secret generation

PR [#672](https://github.com/apache/pulsar-helm-chart/pull/672) removes the need to run `prepare_helm_release.sh` — or any out-of-band script — to seed JWT secrets before installing.

Opt in with `auth.authentication.jwt.generateSecrets.enabled: true`. A `pre-install`/`pre-upgrade` Job mints the signing key (symmetric or RSA) and one token per `auth.superUsers` entry, storing them as the same `<release>-token-*` secrets the rest of the chart already consumes. The Job is idempotent — skipped if the signing key secret exists, and existing token secrets are never overwritten — and supports annotations on generated secrets for tooling like [reflector](https://github.com/emberstack/kubernetes-reflector). Default is `false`, so existing installs are unaffected.

A fully-authenticated cluster can now be deployed with a single `helm install`.

### Standalone deployment mode

PR [#674](https://github.com/apache/pulsar-helm-chart/pull/674) adds a top-level `standalone` toggle that deploys a single Pulsar standalone instance instead of separate ZooKeeper, BookKeeper, Broker, etc. workloads.

The goal is to use the **same Helm chart for minimal development and test deployments on Kubernetes** — local Kind/k3d/minikube, ephemeral CI, developer sandboxes — without a separate chart or installer. Existing values, image overrides, and tooling carry over.

## Upgrading to Helm chart version 4.2.0

### TLS configuration for ZooKeeper has changed

The TLS configuration for ZooKeeper has been changed to fix certificate and private key expiration issues.
This change impacts configurations that have `tls.enabled` and `tls.zookeeper.enabled` set in `values.yaml`.
The revised solution requires the `AdditionalCertificateOutputFormats=true` feature gate to be enabled in the `cert-manager` deployment when using cert-manager versions below 1.15.0.
If you installed `cert-manager` using `./scripts/cert-manager/install-cert-manager.sh`, you can re-run the updated script to set the feature gate. The script currently installs or upgrades cert-manager LTS version 1.12.17, where the feature gate must be explicitly enabled.


## Upgrading to Helm chart version 4.1.0

This version introduces `OpenID` authentication. Setting `auth.authentication.provider` is no longer supported, you need to enable the provider with `auth.authentication.<provider>.enabled`.

In the case of using JWT authentication, you need to set `auth.authentication.jwt.enabled` to `true` in your `values.yaml`.

```yaml
auth:
  authentication:
    enabled: true
    jwt:
      # Enable JWT authentication
      enabled: true
```

## Upgrading from Helm Chart versions before 4.0.0 to 4.0.0 version and above

### Pulsar Proxy service's default type has been changed from `LoadBalancer` to `ClusterIP`

Please check the section "External Access Recommendations" for guidance and also check the security advisory section.
You will need to configure keys under `proxy.service` in your `values.yaml` to preserve existing functionality since the default has been changed.

### kube-prometheus-stack replaced with victoria-metrics-k8s-stack

The `kube-prometheus-stack` was replaced with `victoria-metrics-k8s-stack` in Pulsar Helm chart version 4.0.0. The trigger for the change was incompatibilities discovered in testing with most recent `kube-prometheus-stack` and Prometheus 3.2.1 which failed to scrape Pulsar metrics in certain cases without providing proper error messages or debug information at debug level logging.

[Victoria Metrics](https://docs.victoriametrics.com/) is Apache 2.0 Licensed OSS and it's a fully compatible drop-in replacement for Prometheus which is fast and efficient.

Before upgrading to Pulsar Helm Chart version 4.0.0, it is recommended to disable kube-prometheus-stack in the original Helm chart version that
is used:

```shell
# get the existing values.yaml used for the most recent deployment
helm get values -n <namespace> <pulsar-release-name> > values.yaml
# disable kube-prometheus-stack in the currently used version before upgrading to Pulsar Helm chart 4.0.0
helm upgrade -n <namespace> -f values.yaml --version <your-current-chart-version> --set kube-prometheus-stack.enabled=false  <pulsar-release-name> apachepulsar/pulsar
```

After, this you can proceed with `helm upgrade`.

## Upgrading to Apache Pulsar 2.10.0 and above (or Helm Chart version 3.0.0 and above)

The 2.10.0+ Apache Pulsar docker image is a non-root container, by default. That complicates an upgrade to 2.10.0
because the existing files are owned by the root user but are not writable by the root group. In order to leverage this
new security feature, the Bookkeeper and Zookeeper StatefulSet [securityContexts](https://kubernetes.io/docs/tasks/configure-pod-container/security-context)
are configurable in the [`values.yaml`](charts/pulsar/values.yaml). They default to:

```yaml
  securityContext:
    fsGroup: 0
    fsGroupChangePolicy: "OnRootMismatch"
```

This configuration is ideal for regular Kubernetes clusters where the UID is stable across restarts. If the process
UID is subject to change (like it is in OpenShift), you'll need to set `fsGroupChangePolicy: "Always"`.

The official docker image assumes that it is run as a member of the root group.

If you upgrade to the latest version of the helm chart before upgrading to Pulsar 2.10.0, then when you perform your
first upgrade to version >= 2.10.0, you will need to set `fsGroupChangePolicy: "Always"` on the first upgrade and then
set it back to `fsGroupChangePolicy: "OnRootMismatch"` on subsequent upgrades. This is because the root file won't
mismatch permissions, but the RocksDB lock file will. If you have direct access to the persistent volumes, you can
alternatively run `chgrp -R g+w /pulsar/data` before upgrading.

Here is a sample error you can expect if the RocksDB lock file is not correctly owned by the root group:

```text
2022-05-14T03:45:06,903+0000  ERROR org.apache.bookkeeper.server.Main - Failed to build bookie server
java.io.IOException: Error open RocksDB database
    at org.apache.bookkeeper.bookie.storage.ldb.KeyValueStorageRocksDB.<init>(KeyValueStorageRocksDB.java:199) ~[org.apache.bookkeeper-bookkeeper-server-4.14.4.jar:4.14.4]
    at org.apache.bookkeeper.bookie.storage.ldb.KeyValueStorageRocksDB.<init>(KeyValueStorageRocksDB.java:88) ~[org.apache.bookkeeper-bookkeeper-server-4.14.4.jar:4.14.4]
    at org.apache.bookkeeper.bookie.storage.ldb.KeyValueStorageRocksDB.lambda$static$0(KeyValueStorageRocksDB.java:62) ~[org.apache.bookkeeper-bookkeeper-server-4.14.4.jar:4.14.4]
    at org.apache.bookkeeper.bookie.storage.ldb.LedgerMetadataIndex.<init>(LedgerMetadataIndex.java:68) ~[org.apache.bookkeeper-bookkeeper-server-4.14.4.jar:4.14.4]
    at org.apache.bookkeeper.bookie.storage.ldb.SingleDirectoryDbLedgerStorage.<init>(SingleDirectoryDbLedgerStorage.java:169) ~[org.apache.bookkeeper-bookkeeper-server-4.14.4.jar:4.14.4]
    at org.apache.bookkeeper.bookie.storage.ldb.DbLedgerStorage.newSingleDirectoryDbLedgerStorage(DbLedgerStorage.java:150) ~[org.apache.bookkeeper-bookkeeper-server-4.14.4.jar:4.14.4]
    at org.apache.bookkeeper.bookie.storage.ldb.DbLedgerStorage.initialize(DbLedgerStorage.java:129) ~[org.apache.bookkeeper-bookkeeper-server-4.14.4.jar:4.14.4]
    at org.apache.bookkeeper.bookie.Bookie.<init>(Bookie.java:818) ~[org.apache.bookkeeper-bookkeeper-server-4.14.4.jar:4.14.4]
    at org.apache.bookkeeper.proto.BookieServer.newBookie(BookieServer.java:152) ~[org.apache.bookkeeper-bookkeeper-server-4.14.4.jar:4.14.4]
    at org.apache.bookkeeper.proto.BookieServer.<init>(BookieServer.java:120) ~[org.apache.bookkeeper-bookkeeper-server-4.14.4.jar:4.14.4]
    at org.apache.bookkeeper.server.service.BookieService.<init>(BookieService.java:52) ~[org.apache.bookkeeper-bookkeeper-server-4.14.4.jar:4.14.4]
    at org.apache.bookkeeper.server.Main.buildBookieServer(Main.java:304) ~[org.apache.bookkeeper-bookkeeper-server-4.14.4.jar:4.14.4]
    at org.apache.bookkeeper.server.Main.doMain(Main.java:226) [org.apache.bookkeeper-bookkeeper-server-4.14.4.jar:4.14.4]
    at org.apache.bookkeeper.server.Main.main(Main.java:208) [org.apache.bookkeeper-bookkeeper-server-4.14.4.jar:4.14.4]
Caused by: org.rocksdb.RocksDBException: while open a file for lock: /pulsar/data/bookkeeper/ledgers/current/ledgers/LOCK: Permission denied
    at org.rocksdb.RocksDB.open(Native Method) ~[org.rocksdb-rocksdbjni-6.10.2.jar:?]
    at org.rocksdb.RocksDB.open(RocksDB.java:239) ~[org.rocksdb-rocksdbjni-6.10.2.jar:?]
    at org.apache.bookkeeper.bookie.storage.ldb.KeyValueStorageRocksDB.<init>(KeyValueStorageRocksDB.java:196) ~[org.apache.bookkeeper-bookkeeper-server-4.14.4.jar:4.14.4]
    ... 13 more
```

### Recovering from `helm upgrade` error "unable to build kubernetes objects from current release manifest"

Example of the error message:

```bash
Error: UPGRADE FAILED: unable to build kubernetes objects from current release manifest:
[resource mapping not found for name: "pulsar-bookie" namespace: "pulsar" from "":
no matches for kind "PodDisruptionBudget" in version "policy/v1beta1" ensure CRDs are installed first,
resource mapping not found for name: "pulsar-broker" namespace: "pulsar" from "":
no matches for kind "PodDisruptionBudget" in version "policy/v1beta1" ensure CRDs are installed first,
resource mapping not found for name: "pulsar-zookeeper" namespace: "pulsar" from "":
no matches for kind "PodDisruptionBudget" in version "policy/v1beta1" ensure CRDs are installed first]
```

Helm documentation [explains issues with managing releases deployed using outdated APIs](https://helm.sh/docs/topics/kubernetes_apis/#helm-users) when the Kubernetes cluster has been upgraded
to a version where these APIs are removed. This happens regardless of whether the chart in the upgrade includes supported API versions.
In this case, you can use the following workaround:

1. Install the [Helm mapkubeapis plugin](https://github.com/helm/helm-mapkubeapis):

    ```bash
    helm plugin install https://github.com/helm/helm-mapkubeapis
    ```

2. Run the `helm mapkubeapis` command with the appropriate namespace and release name. In this example, we use the namespace "pulsar" and release name "pulsar":

    ```bash
    helm mapkubeapis --namespace pulsar pulsar
    ```

This workaround addresses the issue by updating in-place Helm release metadata that contains deprecated or removed Kubernetes APIs to a new instance with supported Kubernetes APIs and should allow for a successful Helm upgrade.

## Uninstall

To uninstall the Pulsar Chart, run the following command:

```bash
helm uninstall <pulsar-release-name>
```

For the purposes of continuity, these charts have some Kubernetes objects that are not removed when performing `helm uninstall`.
These items we require you to *conciously* remove them, as they affect re-deployment should you choose to.

* PVCs for stateful data, which you must *consciously* remove
    - ZooKeeper: This is your metadata.
    - BookKeeper: This is your data.
    - Prometheus: This is your metrics data, which can be safely removed.
* Secrets, if generated by our [prepare release script](https://github.com/apache/pulsar-helm-chart/blob/master/scripts/pulsar/prepare_helm_release.sh). They contain secret keys, tokens, etc. You can use [cleanup release script](https://github.com/apache/pulsar-helm-chart/blob/master/scripts/pulsar/cleanup_helm_release.sh) to remove these secrets and tokens as needed.

## Troubleshooting

We've done our best to make these charts as seamless as possible,
occasionally troubles do surface outside of our control. We've collected
tips and tricks for troubleshooting common issues. Please examine these first before raising an [issue](https://github.com/apache/pulsar-helm-chart/issues/new/choose), and feel free to add to them by raising a [Pull Request](https://github.com/apache/pulsar-helm-chart/compare)!

### VictoriaMetrics Troubleshooting

In example commands, k8s is namespace `pulsar` replace with your deployment namespace.

#### VictoriaMetrics Web UI

Connecting to `vmsingle` pod for web UI.

```shell
kubectl port-forward -n pulsar $(kubectl get pods -n pulsar -l app.kubernetes.io/name=vmsingle -o jsonpath='{.items[0].metadata.name}') 8429:8429
```

Now you can access the UI at http://localhost:8429 and http://localhost:8429/vmui (for similar UI as in Prometheus)

#### VictoriaMetrics Scraping debugging UI - Active Targets

Connection to `vmagent` pod for debugging targets.

```shell
kubectl port-forward -n pulsar $(kubectl get pods -n pulsar -l app.kubernetes.io/name=vmagent -o jsonpath='{.items[0].metadata.name}') 8429:8429
```

Now you can access the UI at http://localhost:8429

Active Targets UI
- http://localhost:8429/targets

Scraping Configuration
- http://localhost:8429/config

## Release Process

See [RELEASE.md](RELEASE.md)
