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

SCRIPT_DIR="$(unset CDPATH && cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
CHART_HOME=$(unset CDPATH && cd "$SCRIPT_DIR/../.." && pwd)
cd ${CHART_HOME}

source "${SCRIPT_DIR}/common_auth.sh"

usage() {
    cat <<EOF
This script is used to generate token secret key for a given pulsar helm release.
Options:
       -h,--help                        prints the usage message
       -n,--namespace                   the k8s namespace to install the pulsar helm chart
       -k,--release                     the pulsar helm release name
       -s,--symmetric                   generate symmetric secret key. If not provided, an asymmetric pair of keys are generated.
       -l,--local                       read and write output from local filesystem, do not install secret to kubernetes
Usage:
    $0 --namespace pulsar --release pulsar-dev
EOF
}

symmetric=false

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -n|--namespace)
    namespace="$2"
    shift
    shift
    ;;
    -k|--release)
    release="$2"
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
local_cmd=${file:+-o yaml --dry-run=client >secret.yaml}

function pulsar::jwt::generate_symmetric_key() {
    local secret_name="${release}-token-symmetric-key"

    local tmpdir=$(mktemp -d)
    trap "test -d $tmpdir && rm -rf $tmpdir" RETURN
    local tmpfile=${tmpdir}/SECRETKEY
    docker run --rm -t ${PULSAR_TOKENS_CONTAINER_IMAGE} bin/pulsar tokens create-secret-key > "${tmpfile}"
    kubectl create secret generic ${secret_name} -n ${namespace} --from-file=$tmpfile ${local:+ -o yaml --dry-run=client}
    # if local is true, keep the file available for debugging purposes
    if [[ "${local}" == "true" ]]; then
        mv $tmpfile SECRETKEY
    fi
    rm -rf $tmpdir
}

function pulsar::jwt::generate_asymmetric_key() {
    local secret_name="${release}-token-asymmetric-key"

    local tmpdir=$(mktemp -d)
    trap "test -d $tmpdir && rm -rf $tmpdir" RETURN

    privatekeytmpfile=${tmpdir}/PRIVATEKEY
    publickeytmpfile=${tmpdir}/PUBLICKEY

    # Generate key pair
    docker run --user 0 --rm -t -v ${tmpdir}:/keydir ${PULSAR_TOKENS_CONTAINER_IMAGE} bin/pulsar tokens create-key-pair --output-private-key=/keydir/PRIVATEKEY --output-public-key=/keydir/PUBLICKEY

    kubectl create secret generic ${secret_name} -n ${namespace} --from-file=$privatekeytmpfile --from-file=$publickeytmpfile ${local:+ -o yaml --dry-run=client}

    # if local is true, keep the files available for debugging purposes
    if [[ "${local}" == "true" ]]; then
        mv $privatekeytmpfile PRIVATEKEY
        mv $publickeytmpfile PUBLICKEY
    fi
    rm -rf $tmpdir
}

if [[ "${symmetric}" == "true" ]]; then
    pulsar::jwt::generate_symmetric_key
else
    pulsar::jwt::generate_asymmetric_key
fi
