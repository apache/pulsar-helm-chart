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

# This script is used to upgrade the Victoria Metrics Operator CRDs before running "helm upgrade"
#
# Usage: ./upgrade_vm_operator_crds.sh [VM_OPERATOR_VERSION]
# Use the resolve_vm_operator_version.sh script to get the correct version 
# of the Victoria Metrics Operator from the Helm chart. If no version is provided, a default version will be used.

VM_OPERATOR_VERSION="${1:-"v0.68.0"}"
kubectl apply --server-side --force-conflicts -f "https://github.com/VictoriaMetrics/operator/releases/download/${VM_OPERATOR_VERSION}/crd.yaml"
