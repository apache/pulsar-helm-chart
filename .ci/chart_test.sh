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

set -e


BINDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PULSAR_HOME="$(cd "${BINDIR}/.." && pwd)"
VALUES_FILE=$1
TLS=${TLS:-"false"}
SYMMETRIC=${SYMMETRIC:-"false"}
FUNCTION=${FUNCTION:-"false"}
MANAGER=${MANAGER:-"false"}

source ${PULSAR_HOME}/.ci/helm.sh

# create cluster
ci::create_cluster

ci::helm_repo_add

extra_opts=""
if [[ "x${SYMMETRIC}" == "xtrue" ]]; then
    extra_opts="-s"
fi

if [[ "x${EXTRA_SUPERUSERS}" != "x" ]]; then
    extra_opts="${extra_opts} --pulsar-superusers proxy-admin,broker-admin,admin,${EXTRA_SUPERUSERS}"
fi

install_type="install"
test_action="produce-consume"
if [[ "$UPGRADE_FROM_VERSION" != "" ]]; then
    # install older version of pulsar chart
    PULSAR_CHART_VERSION="$UPGRADE_FROM_VERSION"
    ci::install_pulsar_chart install ${PULSAR_HOME}/.ci/values-common.yaml ${PULSAR_HOME}/${VALUES_FILE} ${extra_opts}    
    install_type="upgrade"
    echo "Wait 10 seconds"
    sleep 10
    # test that we can access the admin api
    ci::test_pulsar_admin_api_access
    # produce messages with old version of pulsar and consume with new version
    ci::test_pulsar_producer_consumer "produce"
    test_action="consume"

    if [[ "$(ci::helm_values_for_deployment | yq .kube-prometheus-stack.enabled)" == "true" ]]; then
        echo "Upgrade Prometheus Operator CRDs before upgrading the deployment"
        ${PULSAR_HOME}/scripts/kube-prometheus-stack/upgrade_prometheus_operator_crds.sh
    fi
fi

PULSAR_CHART_VERSION="local"
# install (or upgrade) pulsar chart
ci::install_pulsar_chart ${install_type} ${PULSAR_HOME}/.ci/values-common.yaml ${PULSAR_HOME}/${VALUES_FILE} ${extra_opts}

echo "Wait 10 seconds"
sleep 10

# check pulsar environment
ci::check_pulsar_environment

# test that we can access the admin api
ci::test_pulsar_admin_api_access
# test producer/consumer
ci::test_pulsar_producer_consumer "${test_action}"

if [[ "$(ci::helm_values_for_deployment | yq .components.functions)" == "true" ]]; then
    # test functions
    ci::test_pulsar_function
fi

if [[ "$(ci::helm_values_for_deployment | yq .components.pulsar_manager)" == "true" ]]; then
    # test manager
    ci::test_pulsar_manager
fi

# delete the cluster
ci::delete_cluster
