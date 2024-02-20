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
PULSAR_CHART_LOCAL=${CHARTS_HOME}/charts/pulsar
PULSAR_CHART_VERSION=${PULSAR_CHART_VERSION:-"local"}
OUTPUT_BIN=${CHARTS_HOME}/output/bin
KIND_BIN=$OUTPUT_BIN/kind
HELM=${OUTPUT_BIN}/helm
KUBECTL=${OUTPUT_BIN}/kubectl
NAMESPACE=pulsar
CLUSTER=pulsar-ci
: ${CLUSTER_ID:=$(uuidgen)}
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

function ci::helm_repo_add() {
    echo "Adding the helm repo ..."
    ${HELM} repo add prometheus-community https://prometheus-community.github.io/helm-charts
    ${HELM} repo update
    echo "Successfully added the helm repo."
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
    local install_type=$1
    local common_value_file=$2
    local value_file=$3
    local extra_opts="$4 $5 $6 $7 $8"
    local install_args

    if [[ "${install_type}" == "install" ]]; then
      echo "Installing the pulsar chart"
      ${KUBECTL} create namespace ${NAMESPACE}
      ci::install_cert_manager
      echo ${CHARTS_HOME}/scripts/pulsar/prepare_helm_release.sh -k ${CLUSTER} -n ${NAMESPACE} ${extra_opts}
      ${CHARTS_HOME}/scripts/pulsar/prepare_helm_release.sh -k ${CLUSTER} -n ${NAMESPACE} ${extra_opts}
      sleep 10

      # install metallb for loadbalancer support
      # following instructions from https://kind.sigs.k8s.io/docs/user/loadbalancer/
      ${KUBECTL} apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
      # wait until metallb is ready
      ${KUBECTL} wait --namespace metallb-system \
                --for=condition=ready pod \
                --selector=app=metallb \
                --timeout=90s
      # configure metallb
      ${KUBECTL} apply -f ${BINDIR}/metallb/metallb-config.yaml
      install_args=""
    else
      install_args="--wait --wait-for-jobs --timeout 300s --debug"
    fi

    CHART_ARGS=""
    if [[ "${PULSAR_CHART_VERSION}" == "local" ]]; then
      set -x
      ${HELM} dependency update ${PULSAR_CHART_LOCAL}
      set +x
      CHART_ARGS="${PULSAR_CHART_LOCAL}"
    else
      set -x
      ${HELM} repo add apache https://pulsar.apache.org/charts
      set +x
      CHART_ARGS="apache/pulsar --dependency-update"
      if [[ "${PULSAR_CHART_VERSION}" != "latest" ]]; then
        CHART_ARGS="${CHART_ARGS} --version ${PULSAR_CHART_VERSION}"
      fi
    fi
    set -x
    ${HELM} template --values ${common_value_file} --values ${value_file} ${CLUSTER} ${CHART_ARGS}
    ${HELM} ${install_type} --values ${common_value_file} --values ${value_file} --namespace=${NAMESPACE} ${CLUSTER} ${CHART_ARGS} ${install_args}
    set +x

    if [[ "${install_type}" == "install" ]]; then
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
      timeout 120s ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bash -c 'until [ "$(curl -s -L http://pulsar-ci-broker:8080/status.html)" == "OK" ]; do sleep 3; done' || { echo >&2 "Timeout waiting..."; ci::print_pod_logs; exit 1; }

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
      echo "Install complete"
    else
      echo "wait until broker is alive"
      timeout 300s ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bash -c 'until nslookup pulsar-ci-broker; do sleep 3; done' || { echo >&2 "Timeout waiting..."; ci::print_pod_logs; exit 1; }
      timeout 120s ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bash -c 'until [ "$(curl -s -L http://pulsar-ci-broker:8080/status.html)" == "OK" ]; do sleep 3; done' || { echo >&2 "Timeout waiting..."; ci::print_pod_logs; exit 1; }
      echo "wait until proxy is alive"
      timeout 300s ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bash -c 'until nslookup pulsar-ci-proxy; do sleep 3; done' || { echo >&2 "Timeout waiting..."; ci::print_pod_logs; exit 1; }
      echo "Upgrade complete"
    fi
}

helm_values_cached=""

function ci::helm_values_for_deployment() {
    if [[ -z "${helm_values_cached}" ]]; then
        helm_values_cached=$(helm get values -n ${NAMESPACE} ${CLUSTER} -a -o yaml)
    fi
    printf "%s" "${helm_values_cached}"
}

function ci::check_pulsar_environment() {
    echo "Wait until pulsar-ci-broker is ready"
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bash -c 'until nslookup pulsar-ci-broker; do sleep 3; done'
    echo "Wait until pulsar-ci-proxy is ready"
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bash -c 'until nslookup pulsar-ci-proxy; do sleep 3; done'
    echo "bookie-0 disk usage"
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-bookie-0 -- df -h
    echo "bookie-0 bookkeeper.conf"
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-bookie-0 -- cat conf/bookkeeper.conf
    echo "bookie-0 bookies list (rw)"
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/bookkeeper shell listbookies -rw | grep ListBookiesCommand
    echo "bookie-0 bookies list (ro)"
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/bookkeeper shell listbookies -ro | grep ListBookiesCommand
}

# function to retry a given commend 3 times with a backoff of 10 seconds in between
function ci::retry() {
  local n=1
  local max=3
  local delay=10
  while true; do
    "$@" && break || {
      if [[ $n -lt $max ]]; then
        ((n++))
        echo "::warning::Command failed. Attempt $n/$max:"
        sleep $delay
      else
        fail "::error::The command has failed after $n attempts."
      fi
    }
  done
}

function ci::test_pulsar_admin_api_access() {
  ci::retry ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/pulsar-admin tenants list
}

function ci::test_create_test_namespace() {
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/pulsar-admin tenants create pulsar-ci
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/pulsar-admin namespaces create pulsar-ci/test
}

function ci::test_pulsar_producer_consumer() {
    action="${1:-"produce-consume"}"
    echo "Testing with ${action}"
    if [[ "$(ci::helm_values_for_deployment | yq .tls.proxy.enabled)" == "true" ]]; then
      PROXY_URL="pulsar+ssl://pulsar-ci-proxy:6651"
    else
      PROXY_URL="pulsar://pulsar-ci-proxy:6650"
    fi
    set -x
    if [[ "${action}" == "produce" || "${action}" == "produce-consume" ]]; then
      ci::test_create_test_namespace
      ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/pulsar-admin topics create pulsar-ci/test/test-topic
      ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/pulsar-admin topics create-subscription -s test pulsar-ci/test/test-topic
      ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/pulsar-client produce -m "test-message" pulsar-ci/test/test-topic
      ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/pulsar-admin topics create-subscription -s test2 pulsar-ci/test/test-topic
      ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/pulsar-client --url "${PROXY_URL}" produce -m "test-message2" pulsar-ci/test/test-topic
    fi
    if [[ "${action}" == "consume" || "${action}" == "produce-consume" ]]; then
      ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/pulsar-client consume -s test pulsar-ci/test/test-topic
      ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/pulsar-client --url "${PROXY_URL}" consume -s test2 pulsar-ci/test/test-topic
    fi
    set +x
}

function ci::wait_function_running() {
    num_running=$(${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bash -c 'bin/pulsar-admin functions status --tenant pulsar-ci --namespace test --name test-function' | jq .numRunning)
    counter=1
    while [[ ${num_running} -lt 1 ]]; do
      ((counter++))
      if [[ $counter -gt 6 ]]; then
        echo >&2 "Timeout waiting..."
        return 1
      fi
      echo "Waiting 15 seconds for function to be running"
      sleep 15
      ${KUBECTL} get pods -n ${NAMESPACE} -l component=function || true
      ${KUBECTL} get events --sort-by=.lastTimestamp -A | tail -n 30 || true
      podname=$(${KUBECTL} get pods -l component=function -n ${NAMESPACE} --no-headers -o custom-columns=":metadata.name") || true
      if [[ -n "$podname" ]]; then
        echo "Function pod is $podname"
        ${KUBECTL} describe pod -n ${NAMESPACE} $podname
        echo "Function pod logs"
        ${KUBECTL} logs -n ${NAMESPACE} $podname
      fi
      num_running=$(${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bash -c 'bin/pulsar-admin functions status --tenant pulsar-ci --namespace test --name test-function' | jq .numRunning)
    done
}

function ci::wait_message_processed() {
    num_processed=$(${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bash -c 'bin/pulsar-admin functions stats --tenant pulsar-ci --namespace test --name test-function' | jq .processedSuccessfullyTotal)
    podname=$(${KUBECTL} get pods -l component=function -n ${NAMESPACE} --no-headers -o custom-columns=":metadata.name")
    counter=1
    while [[ ${num_processed} -lt 1 ]]; do
      ((counter++))
      if [[ $counter -gt 6 ]]; then
        echo >&2 "Timeout waiting..."
        return 1
      fi
      echo "Waiting 15 seconds for message to be processed"
      sleep 15
      echo "Function pod is $podname"
      ${KUBECTL} describe pod -n ${NAMESPACE} $podname
      echo "Function pod logs"
      ${KUBECTL} logs -n ${NAMESPACE} $podname
      ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/pulsar-admin functions stats --tenant pulsar-ci --namespace test --name test-function
      num_processed=$(${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bash -c 'bin/pulsar-admin functions stats --tenant pulsar-ci --namespace test --name test-function' | jq .processedSuccessfullyTotal)
    done
}

function ci::test_pulsar_function() {
    echo "Testing functions"
    echo "Creating function"
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/pulsar-admin functions create --tenant pulsar-ci --namespace test --name test-function --inputs "pulsar-ci/test/test_input" --output "pulsar-ci/test/test_output" --parallelism 1 --classname org.apache.pulsar.functions.api.examples.ExclamationFunction --jar /pulsar/examples/api-examples.jar
    echo "Creating subscription for output topic"
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/pulsar-admin topics create-subscription -s test pulsar-ci/test/test_output
    echo "Waiting for function to be ready"
    # wait until the function is running
    ci::wait_function_running
    echo "Sending input message"
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/pulsar-client produce -m 'hello pulsar function!' pulsar-ci/test/test_input
    echo "Waiting for message to be processed"
    ci::wait_message_processed
    echo "Consuming output message"
    ${KUBECTL} exec -n ${NAMESPACE} ${CLUSTER}-toolset-0 -- bin/pulsar-client consume -s test pulsar-ci/test/test_output
}

function ci::test_pulsar_manager() {
  echo "Testing pulsar manager"

  until ${KUBECTL} get jobs -n ${NAMESPACE} ${CLUSTER}-pulsar-manager-init -o json | jq -r '.status.conditions[] | select (.type | test("Complete")).status' | grep True; do sleep 3; done


  echo "Checking Podname"
  podname=$(${KUBECTL} get pods -n ${NAMESPACE} -l component=pulsar-manager --no-headers -o custom-columns=":metadata.name")
  echo "Getting pulsar manager UI password"
  PASSWORD=$(${KUBECTL} get secret -n ${NAMESPACE} -l component=pulsar-manager -o=jsonpath="{.items[0].data.UI_PASSWORD}" | base64 --decode)

  echo "Getting CSRF_TOKEN"
  CSRF_TOKEN=$(${KUBECTL} exec -n ${NAMESPACE} ${podname} -- curl http://127.0.0.1:7750/pulsar-manager/csrf-token)

  echo "Performing login"
  ${KUBECTL} exec -n ${NAMESPACE} ${podname} -- curl -X POST http://127.0.0.1:9527/pulsar-manager/login \
                                                 -H 'Accept: application/json, text/plain, */*' \
                                                 -H 'Content-Type: application/json' \
                                                 -H "X-XSRF-TOKEN: $CSRF_TOKEN" \
                                                 -H "Cookie: XSRF-TOKEN=$CSRF_TOKEN" \
                                                 -sS -D headers.txt \
                                                 -d '{"username": "pulsar", "password": "'${PASSWORD}'"}'
  LOGIN_TOKEN=$(${KUBECTL} exec -n ${NAMESPACE} ${podname} -- grep "token:" headers.txt | sed 's/^.*: //')
  LOGIN_JSESSIONID=$(${KUBECTL} exec -n ${NAMESPACE} ${podname} -- grep -o "JSESSIONID=[a-zA-Z0-9_]*" headers.txt | sed 's/^.*=//')

  echo "Checking environment"
  envs=$(${KUBECTL} exec -n ${NAMESPACE} ${podname} -- curl -X GET http://localhost:9527/pulsar-manager/environments \
                  -H 'Content-Type: application/json' \
                  -H "token: $LOGIN_TOKEN" \
                  -H "X-XSRF-TOKEN: $CSRF_TOKEN" \
                  -H "username: pulsar" \
                  -H "Cookie: XSRF-TOKEN=$CSRF_TOKEN; JSESSIONID=$LOGIN_JSESSIONID;")
  echo "$envs"
  number_of_envs=$(echo $envs | jq '.total')
  if [ "$number_of_envs" -ne 1 ]; then
    echo "Error: Did not find expected environment"
    exit 1
  fi

  # Force manager to query broker for tenant info. This will require use of the manager's JWT, if JWT authentication is enabled.
  echo "Checking tenants"
  pulsar_env=$(echo $envs | jq -r '.data[0].name')
  tenants=$(${KUBECTL} exec -n ${NAMESPACE} ${podname} -- curl -X GET http://localhost:9527/pulsar-manager/admin/v2/tenants \
                  -H 'Content-Type: application/json' \
                  -H "token: $LOGIN_TOKEN" \
                  -H "X-XSRF-TOKEN: $CSRF_TOKEN" \
                  -H "username: pulsar" \
                  -H "tenant: pulsar" \
                  -H "environment: ${pulsar_env}" \
                  -H "Cookie: XSRF-TOKEN=$CSRF_TOKEN; JSESSIONID=$LOGIN_JSESSIONID;")
  echo "$tenants"
  number_of_tenants=$(echo $tenants | jq '.total')
  if [ "$number_of_tenants" -lt 1 ]; then
    echo "Error: Found no tenants!"
    exit 1
  fi
}
