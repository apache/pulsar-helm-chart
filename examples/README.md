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

# Example `values.yaml` files

This directory contains example value overrides for the Apache Pulsar Helm chart.
Each file is a small, focused override that demonstrates one deployment scenario.
They are **not** complete production configurations — start from the chart
[`values.yaml`](../charts/pulsar/values.yaml) and layer one or more of these
examples on top.

## Finding all available values

These examples only set the keys that differ from the defaults. The full list of
configurable values, with their defaults and inline documentation, is the chart
`values.yaml`. You can view it in any of these ways:

```bash
# from the published chart (after `helm repo add apachepulsar https://pulsar.apache.org/charts`)
helm show values apachepulsar/pulsar
# pin a specific chart version with --version, e.g.
helm show values apachepulsar/pulsar --version 4.6.1

# or from a local checkout
helm show values charts/pulsar
```

The latest version is also browsable on the `master` branch:
<https://github.com/apache/pulsar-helm-chart/blob/master/charts/pulsar/values.yaml>

## How to use

Pass an example to `helm install`/`helm upgrade` with `-f`:

```bash
helm install pulsar apachepulsar/pulsar -f examples/values-one-node.yaml
```

Examples are composable — pass `-f` multiple times and later files win:

```bash
# A single-node cluster secured with self-signed TLS and JWT auth
helm install pulsar apachepulsar/pulsar \
  -f examples/values-one-node.yaml \
  -f examples/values-tls-selfsigned.yaml \
  -f examples/values-jwt-symmetric.yaml
```

You can render the resulting manifests without installing anything to review
what an example produces:

```bash
helm template pulsar charts/pulsar -f examples/values-one-node.yaml
```

## Merging examples into a single file

Repeated `-f` flags are usually all you need, but if you want a single merged
values file (for review, for `helm template`, or to hand to other tooling) you
can use [`merge-values.sh`](merge-values.sh). It deep-merges the given files
(later files win, the same precedence as `-f`) and strips the license header:

```bash
# from the examples/ directory; requires yq (https://github.com/mikefarah/yq)
./merge-values.sh values-jwt-asymmetric.yaml values-oxia.yaml values-one-node.yaml > merged-values.yaml
helm install pulsar apachepulsar/pulsar -f merged-values.yaml
```

Pass `--download`/`-d` to fetch the files by name from the `examples/` directory
on the `master` branch (via `curl`) instead of reading them from a local
checkout:

```bash
./merge-values.sh -d values-jwt-asymmetric.yaml values-oxia.yaml values-one-node.yaml > merged-values.yaml
```

Combined with `-d`, the script itself can be fetched with `curl`, so no checkout
is needed at all:

```bash
# download the script and make it executable
curl -fsSL https://raw.githubusercontent.com/apache/pulsar-helm-chart/refs/heads/master/examples/merge-values.sh -o merge-values.sh
chmod +x merge-values.sh

# -d downloads the named values files from master and merges them to stdout
./merge-values.sh -d values-jwt-symmetric.yaml values-oxia.yaml values-one-node.yaml > merged-values.yaml
helm install pulsar apachepulsar/pulsar -f merged-values.yaml
```

## A note on persistence

By default the chart deploys stateful components (ZooKeeper, BookKeeper) with
`PersistentVolumeClaims` so that data survives pod restarts. Most examples keep
this default. The one deliberate exception is
[`values-no-persistence.yaml`](values-no-persistence.yaml), which uses
`emptyDir` volumes and therefore **loses all data** when a pod restarts or the
cluster is shut down — use it only for ephemeral testing/CI.

## A note on the management UI

These examples use [Dekaf](https://pulsar.apache.org/docs/next/administration-dekaf-ui/)
(`components.dekaf: true`) as the web UI rather than the legacy
`pulsar-manager`. Dekaf connects directly to the broker, so it is only enabled
in examples that deploy a broker.

## Examples by category

### Cluster size and topology

| File | Description |
| ---- | ----------- |
| [`values-one-node.yaml`](values-one-node.yaml) | Minimal distributed cluster with a single replica of each component (ZooKeeper, BookKeeper, broker, proxy). Auto-recovery and anti-affinity are disabled and the managed-ledger ensemble/quorum sizes are set to `1` to fit a single bookie. Persistence is kept enabled. Good for local development on a single node. |
| [`values-standalone.yaml`](values-standalone.yaml) | Runs all of Pulsar in a single standalone process. The distributed components (ZooKeeper, BookKeeper, broker, auto-recovery) are automatically suppressed. Smallest footprint; ideal for development and smoke tests. Includes a commented-out snippet for fronting standalone with the Pulsar proxy. |
| [`values-minikube.yaml`](values-minikube.yaml) | Single-replica cluster tuned for [Minikube](https://minikube.sigs.k8s.io/): anti-affinity off, BookKeeper memory caches minimized, the Dekaf UI enabled. Persistence is kept enabled so data survives pod restarts. |
| [`values-local-cluster.yaml`](values-local-cluster.yaml) | A Pulsar cluster (`metadataPrefix: /cluster1`) that attaches to a **separate** configuration store. Pair it with `values-cs.yaml`, which deploys that configuration store. Disables the bundled monitoring stack and the Dekaf UI is enabled. |

### Metadata store

| File | Description |
| ---- | ----------- |
| [`values-oxia.yaml`](values-oxia.yaml) | Use [Oxia](https://github.com/streamnative/oxia) as the metadata store instead of ZooKeeper (`components.zookeeper: false`, `components.oxia: true`). Pulsar Functions are disabled (`components.functions: false`) because their BookKeeper package storage still requires ZooKeeper. |
| [`values-cs.yaml`](values-cs.yaml) | Deploy **only** ZooKeeper as a shared configuration store (`metadataPrefix: /configuration-store`); all other components are disabled. Intended to be combined with `values-local-cluster.yaml`. |

### Storage

| File | Description |
| ---- | ----------- |
| [`values-local-pv.yaml`](values-local-pv.yaml) | Use node-local persistent volumes (`volumes.local_storage: true`). Requires a local-volume provisioner to be installed first. |
| [`values-no-persistence.yaml`](values-no-persistence.yaml) | **Ephemeral.** Deploys stateful components with `emptyDir` instead of PVCs. All data is lost on pod restart / cluster shutdown. Sets `autoSkipNonRecoverableData` so BookKeeper tolerates the lost state. For throwaway testing/CI only. |
| [`values-bookkeeper-aws.yaml`](values-bookkeeper-aws.yaml) | A 3-bookie cluster using AWS EBS (`gp2`) `PersistentVolumeClaims` for the BookKeeper journal and ledgers. Monitoring stack disabled. |
| [`values-zookeeper-aws.yaml`](values-zookeeper-aws.yaml) | A configuration store running only ZooKeeper backed by AWS EBS (`gp2`) volumes, including the `externalZookeeperServerList` option for building a ZooKeeper cluster that spans namespaces/clusters. |

### Security (TLS and authentication)

| File | Description |
| ---- | ----------- |
| [`values-tls-selfsigned.yaml`](values-tls-selfsigned.yaml) | Enable TLS for proxy, broker and ZooKeeper using a self-signed internal cert-manager issuer. Requires [cert-manager](https://cert-manager.io/). |
| [`values-tls-ca.yaml`](values-tls-ca.yaml) | Enable TLS (including the bookie) using a CA issuer that references an existing `ca-key-pair` secret, with custom DNS SANs for the proxy. Requires cert-manager. |
| [`values-jwt-symmetric.yaml`](values-jwt-symmetric.yaml) | Enable JWT authentication and authorization using a symmetric (shared secret) key (`usingSecretKey: true`). The signing key and per-superuser tokens are generated [in-chart](../README.md#in-chart-jwt-secret-generation) (`generateSecrets.enabled: true`), so a fully authenticated cluster deploys with a single `helm install`. |
| [`values-jwt-asymmetric.yaml`](values-jwt-asymmetric.yaml) | Enable JWT authentication and authorization using an asymmetric (RSA private/public) key pair (`usingSecretKey: false`). The signing key pair and per-superuser tokens are generated [in-chart](../README.md#in-chart-jwt-secret-generation) (`generateSecrets.enabled: true`), so a fully authenticated cluster deploys with a single `helm install`. |

### Monitoring

| File | Description |
| ---- | ----------- |
| [`values-disable-monitoring.yaml`](values-disable-monitoring.yaml) | Disable the bundled `victoria-metrics-k8s-stack` monitoring stack and all component `PodMonitor` resources (so the chart does not require the monitoring CRDs). |

### Other

| File | Description |
| ---- | ----------- |
| [`values-init-containers.yaml`](values-init-containers.yaml) | Demonstrates attaching custom `initContainers` to each component (ZooKeeper, BookKeeper, auto-recovery, broker, proxy, toolset). |
| [`values-testing.yaml`](values-testing.yaml) | Settings handy for test environments: anti-affinity off, aggressive BookKeeper/broker disk cleanup, faster ledger rollover and inactive-topic deletion. Not for production. |
