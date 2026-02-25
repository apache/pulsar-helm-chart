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

# Use this script to resolve the Victoria Metrics Operator application version from the Helm chart and print it to stdout.

if ! command -v yq &>/dev/null; then
    echo "yq is not installed. Please install yq to run this script." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# Run "helm dependency update" in charts/pulsar
cd "$SCRIPT_DIR/../../charts/pulsar"
helm dependency update 2>/dev/null 1>&2
tar -zxf charts/victoria-metrics-k8s-stack-*.tgz \
  --to-stdout victoria-metrics-k8s-stack/charts/victoria-metrics-operator/Chart.yaml | yq .appVersion