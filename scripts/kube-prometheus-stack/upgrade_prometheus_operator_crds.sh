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

# This script is used to upgrade the Prometheus Operator CRDs before running "helm upgrade"
# source: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack#upgrading-an-existing-release-to-a-new-major-version
# "Run these commands to update the CRDs before applying the upgrade."
PROMETHEUS_OPERATOR_VERSION="${1:-"0.77.1"}"
PREFIX_URL="https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v${PROMETHEUS_OPERATOR_VERSION}/example/prometheus-operator-crd"
for crd in alertmanagerconfigs alertmanagers podmonitors probes prometheusagents prometheuses prometheusrules scrapeconfigs servicemonitors thanosrulers; do
  # "--force-conflicts" is required to upgrade the CRDs. Following instructions from https://github.com/prometheus-community/helm-charts/issues/2489
  kubectl apply --server-side --force-conflicts -f "${PREFIX_URL}/monitoring.coreos.com_${crd}.yaml"
done