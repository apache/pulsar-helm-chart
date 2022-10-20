#!/usr/bin/env bash
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
BINDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PULSAR_HOME="$(cd "${BINDIR}/.." && pwd)"
CHARTS_HOME=${PULSAR_HOME}
OUTPUT_BIN=${CHARTS_HOME}/output/bin
KIND_BIN=$OUTPUT_BIN/kind
HELM=${OUTPUT_BIN}/helm
KUBECTL=${OUTPUT_BIN}/kubectl
NAMESPACE=pulsar
CLUSTER=pulsar-ci
CLUSTER_ID=$(uuidgen)
K8S_LOGS_DIR="${K8S_LOGS_DIR:-/tmp/k8s-logs}"
export PATH="$OUTPUT_BIN:$PATH"

# brew package 'coreutils' is required on MacOSX
# coreutils includes the 'timeout' command
if [[ "$OSTYPE" == "darwin"* ]]; then
    brew_gnubin_packages=(coreutils)
    if ! type -P brew &>/dev/null; then
        echo "On MacOSX, you must install required binaries with the following command:"
        echo "brew install" "${brew_gnubin_packages[@]}"
        exit 1
    fi
    for dep in "${brew_gnubin_packages[@]}"; do
        path_element="$(brew --prefix)/opt/${dep}/libexec/gnubin"
        if [ ! -d "${path_element}" ]; then
            echo "'${path_element}' is missing. Quick fix: 'brew install ${dep}'."
            echo "On MacOSX, you must install required binaries with the following command:"
            echo "brew install" "${brew_gnubin_packages[@]}"
            exit 1
        fi
        PATH="${path_element}:$PATH"
    done
    export PATH
fi

function ci::create_cluster() {
    echo "Creating a kind cluster ..."
    ${CHARTS_HOME}/hack/kind-cluster-build.sh --name pulsar-ci-${CLUSTER_ID} -c 1 -v 10
    echo "Successfully created a kind cluster."
}

function ci::delete_cluster() {
    echo "Deleting a kind cluster ..."
    kind delete cluster --name=pulsar-ci-${CLUSTER_ID}
    echo "Successfully delete a kind cluster."
}

function ci::install_cert_manager() {
    echo "Installing the cert-manager ..."
    ${KUBECTL} create namespace cert-manager
    ${CHARTS_HOME}/scripts/cert-manager/install-cert-manager.sh
    WC=$(${KUBECTL} get pods -n cert-manager --field-selector=status.phase=Running | wc -l)
    while [[ ${WC} -lt 3 ]]; do
      echo ${WC};
      sleep 15
      ${KUBECTL} get pods -n cert-manager
      ${KUBECTL} get events --sort-by=.lastTimestamp -A | tail -n 30 || true
      WC=$(${KUBECTL} get pods -n cert-manager --field-selector=status.phase=Running | wc -l)
    done
    echo "Successfully installed the cert manager."
}

function ci::print_pod_logs() {
    echo "Logs for all pulsar containers:"
    for k8sobject in $(${KUBECTL} get pods,jobs -n ${NAMESPACE} -l app=pulsar -o=name); do
      ${KUBECTL} logs -n ${NAMESPACE} "$k8sobject" --all-containers=true --ignore-errors=true --prefix=true --tail=100 || true
    done;
}

function ci::collect_k8s_logs() {
    mkdir -p "${K8S_LOGS_DIR}" && cd "${K8S_LOGS_DIR}"
    echo "Collecting k8s logs to ${K8S_LOGS_DIR}"
    for k8sobject in $(${KUBECTL} get pods,jobs -n ${NAMESPACE} -l app=pulsar -o=name); do
      filebase="${k8sobject//\//_}"
      ${KUBECTL} logs -n ${NAMESPACE} "$k8sobject" --all-containers=true --ignore-errors=true --prefix=true > "${filebase}.$$.log.txt" || true
      ${KUBECTL} logs -n ${NAMESPACE} "$k8sobject" --all-containers=true --ignore-errors=true --prefix=true --previous=true > "${filebase}.previous.$$.log.txt" || true
    done;
    ${KUBECTL} get events --sort-by=.lastTimestamp -A > events.$$.log.txt || true
    ${KUBECTL} get events --sort-by=.lastTimestamp -A -o yaml > events.$$.log.yaml || true
    ${KUBECTL} get -n ${NAMESPACE} all -o yaml > k8s_resources.$$.yaml || true
}

function ci::install_pulsar_chart() {
    local value_file=$1
    local extra_opts=$2

    echo "Installing the pulsar chart"
    ${KUBECTL} create namespace ${NAMESPACE}
    ci::install_cert_manager
    echo ${CHARTS_HOME}/scripts/pulsar/prepare_helm_release.sh -k ${CLUSTER} -n ${NAMESPACE} ${extra_opts}
    ${CHARTS_HOME}/scripts/pulsar/prepare_helm_release.sh -k ${CLUSTER} -n ${NAMESPACE} ${extra_opts}
    sleep 10

    echo ${HELM} dependency update ${CHARTS_HOME}/charts/pulsar
    ${HELM} dependency update ${CHARTS_HOME}/charts/pulsar
    echo ${HELM} install --set initialize=true --values ${value_file} ${CLUSTER} ${CHARTS_HOME}/charts/pulsar
    ${HELM} template --values ${value_file} ${CLUSTER} ${CHARTS_HOME}/charts/pulsar
    ${HELM} install --set initialize=true --values ${value_file} --namespace=${NAMESPACE} ${CLUSTER} ${CHARTS_HOME}/charts/pulsar

    echo "wait until broker is alive"
    WC=$(${KUBECTL} get pods -n ${NAMESPACE} --field-selector=status.phase=Running | grep ${CLUSTER}-broker | wc -l)
    counter=1
    while [[ ${WC} -lt 1 ]]; do
      ((counter++))
      echo ${WC};
      sleep 15
      ${KUBECTL} get pods,jobs -n ${NAMESPACE}
      ${KUBECTL} get events --sort-by=.lastTimestamp -A | tail -n 30 || true
      if [[ $((counter % 20)) -eq 0 ]]; then
        ci::print_pod_logs
        if [[ $counter -gt 100 ]]; then
          echo >&2 "Timeout waiting..."
          exit 1
        fi
      fi
      WC=$(${KUBECTL} get pods -n ${NAMESPACE} | grep ${CLUSTER}-broker | wc -l)
      if [[ ${WC} -gt 1 ]]; then
        ${KUBECTL} describe pod -n ${NAMESPACE} pulsar-ci-broker-0
        ${KUBECTL} logs -n ${NAMESPACE} pulsar-ci-broker-0
      fi
      WC=$(${KUBECTL} get pods -n ${NAMESPACE} --field-selector=status.phase=Running | grep ${CLUSTER}-broker | wc -l)
    done
    timeout 300s ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bash -c 'until nslookup pulsar-ci-broker; do sleep 3; done' || { echo >&2 "Timeout waiting..."; ci::print_pod_logs; exit 1; }
    timeout 120s ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bash -c 'until [ "$(curl -L http://pulsar-ci-broker:8080/status.html)" == "OK" ]; do sleep 3; done' || { echo >&2 "Timeout waiting..."; ci::print_pod_logs; exit 1; }

    WC=$(${KUBECTL} get pods -n ${NAMESPACE} --field-selector=status.phase=Running | grep ${CLUSTER}-proxy | wc -l)
    counter=1
    while [[ ${WC} -lt 1 ]]; do
      ((counter++))
      echo ${WC};
      sleep 15
      ${KUBECTL} get pods,jobs -n ${NAMESPACE}
      ${KUBECTL} get events --sort-by=.lastTimestamp -A | tail -n 30 || true
      if [[ $((counter % 8)) -eq 0 ]]; then
        ci::print_pod_logs
        if [[ $counter -gt 16 ]]; then
          echo >&2 "Timeout waiting..."
          exit 1
        fi
      fi
      WC=$(${KUBECTL} get pods -n ${NAMESPACE} --field-selector=status.phase=Running | grep ${CLUSTER}-proxy | wc -l)
    done
    timeout 300s ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bash -c 'until nslookup pulsar-ci-proxy; do sleep 3; done' || { echo >&2 "Timeout waiting..."; ci::print_pod_logs; exit 1; }
    # ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bash -c 'until [ "$(curl -L http://pulsar-ci-proxy:8080/status.html)" == "OK" ]; do sleep 3; done'
}

function ci::test_pulsar_producer_consumer() {
    sleep 120
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bash -c 'until nslookup pulsar-ci-broker; do sleep 3; done'
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bash -c 'until nslookup pulsar-ci-proxy; do sleep 3; done'
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-bookie-0 -- df -h
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-bookie-0 -- cat conf/bookkeeper.conf
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/bookkeeper shell listbookies -rw
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/bookkeeper shell listbookies -ro
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/pulsar-admin tenants create pulsar-ci
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/pulsar-admin namespaces create pulsar-ci/test
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/pulsar-admin topics create pulsar-ci/test/test-topic
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/pulsar-admin topics create-subscription -s test pulsar-ci/test/test-topic
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/pulsar-client produce -m "test-message" pulsar-ci/test/test-topic
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/pulsar-client consume -s test pulsar-ci/test/test-topic
}

function ci::wait_function_running() {
    num_running=$(${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bash -c 'bin/pulsar-admin functions status --tenant pulsar-ci --namespace test --name test-function | bin/jq .numRunning')
    while [[ ${num_running} -lt 1 ]]; do
      echo ${num_running}
      sleep 15
      ${KUBECTL} get pods -n ${NAMESPACE} --field-selector=status.phase=Running
      ${KUBECTL} get events --sort-by=.lastTimestamp -A | tail -n 30 || true
      num_running=$(${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bash -c 'bin/pulsar-admin functions status --tenant pulsar-ci --namespace test --name test-function | bin/jq .numRunning')
    done
}

function ci::wait_message_processed() {
    num_processed=$(${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bash -c 'bin/pulsar-admin functions stats --tenant pulsar-ci --namespace test --name test-function | bin/jq .processedSuccessfullyTotal')
    while [[ ${num_processed} -lt 1 ]]; do
      echo ${num_processed}
      sleep 15
      ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/pulsar-admin functions stats --tenant pulsar-ci --namespace test --name test-function
      num_processed=$(${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bash -c 'bin/pulsar-admin functions stats --tenant pulsar-ci --namespace test --name test-function | bin/jq .processedSuccessfullyTotal')
    done
}

function ci::test_pulsar_function() {
    sleep 120
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bash -c 'until nslookup pulsar-ci-broker; do sleep 3; done'
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bash -c 'until nslookup pulsar-ci-proxy; do sleep 3; done'
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-bookie-0 -- df -h
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/bookkeeper shell listbookies -rw
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/bookkeeper shell listbookies -ro
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/pulsar-admin functions create --tenant pulsar-ci --namespace test --name test-function --inputs "pulsar-ci/test/test_input" --output "pulsar-ci/test/test_output" --parallelism 1 --classname org.apache.pulsar.functions.api.examples.ExclamationFunction --jar /pulsar/examples/api-examples.jar

    # wait until the function is running
    # TODO: re-enable function test
    # ci::wait_function_running
    # ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/pulsar-client produce -m "hello pulsar function!" pulsar-ci/test/test_input
    # ci::wait_message_processed
}
