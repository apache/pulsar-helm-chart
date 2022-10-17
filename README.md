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

Read [Deploying Pulsar on Kubernetes](http://pulsar.apache.org/docs/deploy-kubernetes/) for more details.

## Features

This Helm Chart includes all the components of Apache Pulsar for a complete experience.

- [x] Pulsar core components:
    - [x] ZooKeeper
    - [x] Bookies
    - [x] Brokers
    - [x] Functions
    - [x] Proxies
- [x] Management & monitoring components:
    - [x] Pulsar Manager
    - [x] Prometheus
    - [x] Grafana

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
        - [x] ZooKeeper
    - [x] Authentication
        - [x] JWT
        - [ ] Mutal TLS
        - [ ] Kerberos
    - [x] Authorization
    - [x] Non-root broker, bookkeeper, proxy, and zookeeper containers (version 2.10.0 and above)
- [x] Storage
    - [x] Non-persistence storage
    - [x] Persistence Volume
    - [x] Local Persistent Volumes
    - [ ] Tiered Storage
- [x] Functions
    - [x] Kubernetes Runtime
    - [x] Process Runtime
    - [x] Thread Runtime
- [x] Operations
    - [x] Independent Image Versions for all components, enabling controlled upgrades

## Requirements

In order to use this chart to deploy Apache Pulsar on Kubernetes, the followings are required.

1. kubectl 1.18 or higher, compatible with your cluster ([+/- 1 minor release from your cluster](https://kubernetes.io/docs/tasks/tools/install-kubectl/#before-you-begin))
2. Helm v3 (3.0.2 or higher)
3. A Kubernetes cluster, version 1.18 or higher.

## Environment setup

Before proceeding to deploying Pulsar, you need to prepare your environment.

### Tools

`helm` and `kubectl` need to be [installed on your computer](https://pulsar.apache.org/docs/helm-tools/).

## Add to local Helm repository

To add this chart to your local Helm repository:

```bash
helm repo add apache https://pulsar.apache.org/charts
```

To use the helm chart:

```bash
helm install <release-name> apache/pulsar
```

## Kubernetes cluster preparation

You need a Kubernetes cluster whose version is 1.18 or higher in order to use this chart, due to the usage of certain Kubernetes features.

We provide some instructions to guide you through the preparation: http://pulsar.apache.org/docs/helm-prepare/

## Deploy Pulsar to Kubernetes

1. Clone the Pulsar Helm charts repository.

    ```bash
    git clone https://github.com/apache/pulsar-helm-chart
    ```
    ```bash
    cd pulsar-helm-chart
    ```

2. Run `prepare_helm_release.sh` to create required kubernetes resources for installing this Helm chart.
    - A k8s namespace for installing the Pulsar release (if `-c` is specified)
    - Create the JWT secret keys and tokens for three superusers: `broker-admin`, `proxy-admin`, and `admin`.
      By default, it generates asymmetric pubic/private key pair. You can choose to generate symmetric secret key
      by specifying `--symmetric` in the following command.
        - `proxy-admin` role is used for proxies to communicate to brokers.
        - `broker-admin` role is used for inter-broker communications.
        - `admin` role is used by the admin tools.

    ```bash
    ./scripts/pulsar/prepare_helm_release.sh -n <k8s-namespace> -k <pulsar-release-name> -c
    ```

3. Use the Pulsar Helm charts to install Apache Pulsar. 

    This command installs and starts Apache Pulsar.

    ```bash 
    $ helm install <pulsar-release-name> apache/pulsar
    ```

5. Access the Pulsar cluster

    The default values will create a `ClusterIP` for the proxy you can use to interact with the cluster. To find the IP address of proxy use:

    ```bash
    kubectl get service -n <k8s-namespace>
    ```

For more information, please follow our detailed
[quick start guide](https://pulsar.apache.org/docs/getting-started-helm/).

## Customize the deployment 

We provide a [detailed guideline](https://pulsar.apache.org/docs/helm-deploy/) for you to customize
the Helm Chart for a production-ready deployment.

You can also checkout out the example values file for different deployments.

- [Deploy ZooKeeper only](examples/values-cs.yaml)
- [Deploy a Pulsar cluster with an external configuration store](examples/values-cs.yaml)
- [Deploy a Pulsar cluster with local persistent volume](examples/values-local-pv.yaml)
- [Deploy a Pulsar cluster to Minikube](examples/values-minikube.yaml)
- [Deploy a Pulsar cluster with no persistence](examples/values-no-persistence.yaml)
- [Deploy a Pulsar cluster with TLS encryption](examples/values-tls.yaml)
- [Deploy a Pulsar cluster with JWT authentication using symmetric key](examples/values-jwt-symmetric.yaml)
- [Deploy a Pulsar cluster with JWT authentication using asymmetric key](examples/values-jwt-asymmetric.yaml)

## Upgrading

Once your Pulsar Chart is installed, configuration changes and chart
updates should be done using `helm upgrade`.

```bash
helm repo add apache https://pulsar.apache.org/charts
helm repo update
helm get values <pulsar-release-name> > pulsar.yaml
helm upgrade -f pulsar.yaml \
    <pulsar-release-name> apache/pulsar
```

For more detailed information, see our [Upgrading](http://pulsar.apache.org/docs/helm-upgrade/) guide.

## Upgrading to 2.10.0 and above

The 2.10.0+ Apache Pulsar docker image is a non-root container, by default. That complicates an upgrade to 2.10.0
because the existing files are owned by the root user but are not writable by the root group. In order to leverage this
new security feature, the Bookkeeper and Zookeeper StatefulSet [securityContexts](https://kubernetes.io/docs/tasks/configure-pod-container/security-context)
are configurable in the `values.yaml`. They default to:

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

## Uninstall

To uninstall the Pulsar Chart, run the following command:

```bash
helm delete <pulsar-release-name>
```

For the purposes of continuity, these charts have some Kubernetes objects that are not removed when performing `helm delete`.
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

## Release Process

1. Bump the version in [charts/pulsar/Chart.yaml](https://github.com/apache/pulsar-helm-chart/blob/master/charts/pulsar/Chart.yaml#L24).

2. Send a pull request for reviews.

3. After the pull request is approved, merge it. The release workflow will be triggered automatically.
   - It creates a tag named `pulsar-<version>`.
   - Published the packaged helm chart to Github releases.
   - Update the `charts/index.yaml` in Pulsar website.

4. Trigger the Pulsar website build to make the release available under https://pulsar.apache.org/charts.
