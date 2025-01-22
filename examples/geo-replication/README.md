# Apache Pulsar geo-replication

This example is used to test apache pulsar geo-replication in the same namespace with self signed certificates :

1. Install the global zookeeper cluster with `values-global-zookeeper.yaml` values. 
   
   It will also create the CA issuer used to create certificates for all components.

   The helm release name is supposed to be `global-zookeeper`, otherwise you nedd to change `broker.configData.configurationStoreServers` in ths following pulsar clusters values.

2. Install the first pulsar cluster with `values-pulsar-cluster-1.yaml` values.

3. Install the second pulsar cluster with `values-pulsar-cluster-2.yaml` values.

When connecting to the global zookeeper, you can see the 2 pulsar clusters :

```
$ kubectl exec global-zookeeper-zookeeper-0 -i -t -- /pulsar/bin/pulsar zookeeper-shell
...
[zk: localhost:2181(CONNECTED) 0] ls /
[admin, zookeeper]
[zk: localhost:2181(CONNECTED) 1] ls /admin
[clusters, policies]
[zk: localhost:2181(CONNECTED) 2] ls /admin/clusters
[cluster-1, cluster-2]
```
