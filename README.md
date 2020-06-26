# Pulsar Helm Chart

Customized version of [official apache helm chart](https://github.com/apache/pulsar-helm-chart).

Read [Deploying Pulsar on Kubernetes](http://pulsar.apache.org/docs/en/deploy-kubernetes/) for more details.

### Steps to package and publish the chart

- Make sure chart version is updated after any changes in chart
- Package apache pulsar chart</br>
`$ helm package stable/apache-pulsar -d docs/packages`
- Update the index file</br>
`$ helm repo index ./docs/packages  --merge=../index.yaml`

### Chart url
https://github.optum.com/pages/link/pulsar-chart/

### Steps to update the chart from apache repo

- Clone this repo
- Add apache pulsar chart remote
- Set upstream of your branch to pulsar remote
- Pull and resolve conflicts
- Switch upstream of your branch to link remote