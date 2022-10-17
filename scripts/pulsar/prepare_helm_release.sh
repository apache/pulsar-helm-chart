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

CHART_HOME=$(unset CDPATH && cd $(dirname "${BASH_SOURCE[0]}")/../.. && pwd)
cd ${CHART_HOME}

usage() {
    cat <<EOF
This script is used to bootstrap the pulsar namespace before deploying a helm chart. 
Options:
       -h,--help                        prints the usage message
       -n,--namespace                   the k8s namespace to install the pulsar helm chart
       -k,--release                     the pulsar helm release name
       -s,--symmetric                   generate symmetric secret key. If not provided, an asymmetric pair of keys are generated.
       --pulsar-superusers              the superusers of pulsar cluster. a comma separated list of super users.
       -c,--create-namespace            flag to create k8s namespace.
       -l,--local                       read and write output from local filesystem, do not deploy to kubernetes
Usage:
    $0 --namespace pulsar --release pulsar-release
EOF
}

symmetric=false
create_namespace=false

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -n|--namespace)
    namespace="$2"
    shift
    shift
    ;;
    -c|--create-namespace)
    create_namespace=true
    shift
    ;;
    -k|--release)
    release="$2"
    shift
    shift
    ;;
    --pulsar-superusers)
    pulsar_superusers="$2"
    shift
    shift
    ;;
    -s|--symmetric)
    symmetric=true
    shift
    ;;
    -l|--local)
    local=true
    shift
    ;;
    -h|--help)
    usage
    exit 0
    ;;
    *)
    echo "unknown option: $key"
    usage
    exit 1
    ;;
esac
done

namespace=${namespace:-pulsar}
release=${release:-pulsar-dev}
pulsar_superusers=${pulsar_superusers:-"proxy-admin,broker-admin,admin"}

function new_k8s_object() {
    if [[ "${local}" == "true" ]]; then
        echo ---
    fi
}

function do_create_namespace() {
    if [[ "${create_namespace}" == "true" ]]; then
        new_k8s_object
        kubectl create namespace ${namespace} ${local:+ -o yaml --dry-run=client}
    fi
}

do_create_namespace

kubectl get namespace "${namespace}" > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "error: failed to get namespace '${namespace}'"
  echo "please check that this namespace exists, or use the '-c' option to create it"
  exit 1
fi

extra_opts=""
if [[ "${symmetric}" == "true" ]]; then
  extra_opts="${extra_opts} -s"
fi

if [[ "${local}" == "true" ]]; then
  extra_opts="${extra_opts} -l"
fi

echo "generate the token keys for the pulsar cluster" >&2
new_k8s_object
${CHART_HOME}/scripts/pulsar/generate_token_secret_key.sh -n ${namespace} -k ${release} ${extra_opts}

echo "generate the tokens for the super-users: ${pulsar_superusers}" >&2

IFS=', ' read -r -a superusers <<< "$pulsar_superusers"
for user in "${superusers[@]}"
do
    echo "generate the token for $user" >&2
    new_k8s_object
    ${CHART_HOME}/scripts/pulsar/generate_token.sh -n ${namespace} -k ${release} -r ${user} ${extra_opts} 
done

echo "-------------------------------------" >&2
echo >&2
echo "The jwt token secret keys are generated under:" >&2
if [[ "${symmetric}" == "true" ]]; then
    echo "    - '${release}-token-symmetric-key'" >&2
else
    echo "    - '${release}-token-asymmetric-key'" >&2
fi
echo >&2

echo "The jwt tokens for superusers are generated and stored as below:" >&2
for user in "${superusers[@]}"
do
    echo "    - '${user}':secret('${release}-token-${user}')" >&2
done
echo >&2

