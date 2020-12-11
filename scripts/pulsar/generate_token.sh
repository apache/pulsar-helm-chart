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

CHART_HOME=$(unset CDPATH && cd $(dirname "${BASH_SOURCE[0]}")/../.. && pwd)
cd ${CHART_HOME}

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

source ${CHART_HOME}/scripts/pulsar/common_auth.sh

pulsar::ensure_pulsarctl

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
        echo "kubectl get -n ${namespace} secrets ${secret_name} -o jsonpath="{.data.${type}}" | base64 --decode > ${tmpfile}"
        kubectl get -n ${namespace} secrets ${secret_name} -o jsonpath="{.data['${type}']}" | base64 --decode > ${tmpfile}
    fi
}

function pulsar::jwt::generate_symmetric_token() {
    local token_name="${release}-token-${role}"
    local secret_name="${release}-token-symmetric-key"

    tmpfile=$(mktemp)
    trap "test -f $tmpfile && rm $tmpfile" RETURN
    tokentmpfile=$(mktemp)
    trap "test -f $tokentmpfile && rm $tokentmpfile" RETURN
    pulsar::jwt::get_secret SECRETKEY ${tmpfile} ${secret_name}
    ${PULSARCTL_BIN} token create -a HS256 --secret-key-file ${tmpfile} --subject ${role} 2&> ${tokentmpfile}
    newtokentmpfile=$(mktemp)
    tr -d '\n' < ${tokentmpfile} > ${newtokentmpfile}
    echo "kubectl create secret generic ${token_name} -n ${namespace} --from-file="TOKEN=${newtokentmpfile}" --from-literal="TYPE=symmetric" ${local:+ -o yaml --dry-run=client}"
    kubectl create secret generic ${token_name} -n ${namespace} --from-file="TOKEN=${newtokentmpfile}" --from-literal="TYPE=symmetric" ${local:+ -o yaml --dry-run=client}
}

function pulsar::jwt::generate_asymmetric_token() {
    local token_name="${release}-token-${role}"
    local secret_name="${release}-token-asymmetric-key"

    privatekeytmpfile=$(mktemp)
    trap "test -f $privatekeytmpfile && rm $privatekeytmpfile" RETURN
    tokentmpfile=$(mktemp)
    trap "test -f $tokentmpfile && rm $tokentmpfile" RETURN
    pulsar::jwt::get_secret PRIVATEKEY ${privatekeytmpfile} ${secret_name}
    ${PULSARCTL_BIN} token create -a RS256 --private-key-file ${privatekeytmpfile} --subject ${role} 2&> ${tokentmpfile}
    newtokentmpfile=$(mktemp)
    tr -d '\n' < ${tokentmpfile} > ${newtokentmpfile}
    kubectl create secret generic ${token_name} -n ${namespace} --from-file="TOKEN=${newtokentmpfile}" --from-literal="TYPE=asymmetric" ${local:+ -o yaml --dry-run=client}
}

if [[ "${symmetric}" == "true" ]]; then
    pulsar::jwt::generate_symmetric_token
else
    pulsar::jwt::generate_asymmetric_token
fi
