# pulsar-chart
a temp helm chart repo, until link/charts is automated

### Steps to update the chart

- Make sure chart version is updated after any changes in chart
- Package apache pulsar chart</br>
`$ helm package stable/apache-pulsar -d docs/packages`
- Update the index file</br>
`$ helm repo index ./docs/packages  --merge=../index.yaml`