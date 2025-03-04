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
This script is used to generate token for a given pulsar role.
Options:
       -h,--help                        prints the usage message
       -n,--namespace                   the k8s namespace to install the pulsar helm chart
       -k,--release                     the pulsar helm release name
       -r,--role                        the pulsar role
       -s,--symmetric                   use symmetric secret key for generating the token. If not provided, the private key of an asymmetric pair of keys is used.
       -l,--local                       read and write output from local filesystem, do not install secret to kubernetes
Usage:
    $0 --namespace pulsar --release pulsar-dev -c <pulsar-role>
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
    -r|--role)
    role="$2"
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

if [[ "x${role}" == "x" ]]; then
    echo "No pulsar role is provided!"
    usage
    exit 1
fi

namespace=${namespace:-pulsar}
release=${release:-pulsar-dev}

function pulsar::jwt::get_secret() {
    local type=$1
    local tmpfile=$2
    local secret_name=$3
    echo ${secret_name}
    if [[ "${local}" == "true" ]]; then
        cp ${type} ${tmpfile}
    else
        kubectl get -n ${namespace} secrets ${secret_name} -o jsonpath="{.data['${type}']}" | base64 --decode > ${tmpfile}
    fi
}

function pulsar::jwt::generate_symmetric_token() {
    local token_name="${release}-token-${role}"
    local secret_name="${release}-token-symmetric-key"


    local tmpdir=$(mktemp -d)
    trap "test -d $tmpdir && rm -rf $tmpdir" RETURN
    secretkeytmpfile=${tmpdir}/secret.key
    tokentmpfile=${tmpdir}/token.jwt

    pulsar::jwt::get_secret SECRETKEY ${secretkeytmpfile} ${secret_name}

    docker run --user 0 --rm -t -v ${tmpdir}:/keydir ${PULSAR_TOKENS_CONTAINER_IMAGE} bin/pulsar tokens create -a HS256 --subject "${role}" --secret-key=file:/keydir/secret.key > ${tokentmpfile}
    
    newtokentmpfile=${tmpdir}/token.jwt.new
    tr -d '\n' < ${tokentmpfile} > ${newtokentmpfile}
    kubectl create secret generic ${token_name} -n ${namespace} --from-file="TOKEN=${newtokentmpfile}" --from-literal="TYPE=symmetric" ${local:+ -o yaml --dry-run=client}
    rm -rf $tmpdir
}

function pulsar::jwt::generate_asymmetric_token() {
    local token_name="${release}-token-${role}"
    local secret_name="${release}-token-asymmetric-key"

    local tmpdir=$(mktemp -d)
    trap "test -d $tmpdir && rm -rf $tmpdir" RETURN

    privatekeytmpfile=${tmpdir}/privatekey.der
    tokentmpfile=${tmpdir}/token.jwt

    pulsar::jwt::get_secret PRIVATEKEY ${privatekeytmpfile} ${secret_name}

    # Generate token
    docker run --user 0 --rm -t -v ${tmpdir}:/keydir ${PULSAR_TOKENS_CONTAINER_IMAGE} bin/pulsar tokens create -a RS256 --subject "${role}" --private-key=file:/keydir/privatekey.der > ${tokentmpfile}

    newtokentmpfile=${tmpdir}/token.jwt.new
    tr -d '\n' < ${tokentmpfile} > ${newtokentmpfile}
    kubectl create secret generic ${token_name} -n ${namespace} --from-file="TOKEN=${newtokentmpfile}" --from-literal="TYPE=asymmetric" ${local:+ -o yaml --dry-run=client}
    rm -rf $tmpdir
}

if [[ "${symmetric}" == "true" ]]; then
    pulsar::jwt::generate_symmetric_token
else
    pulsar::jwt::generate_asymmetric_token
fi
