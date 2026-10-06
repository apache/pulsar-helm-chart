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

set -euo pipefail

chart_dir=${1:-charts/pulsar}
helm_bin=${HELM_BIN:-helm}
release_name=myrelease
namespace=mynamespace
components=(proxy broker function-worker bookie recovery toolset zookeeper)

render_certificates() {
  local san_mode=$1

  "$helm_bin" template "$release_name" "$chart_dir" \
    --namespace "$namespace" \
    --show-only templates/tls-certs-internal.yaml \
    --set certs.internal_issuer.enabled=true \
    --set tls.enabled=true \
    --set tls.common.sanMode="$san_mode" \
    --set tls.proxy.enabled=true \
    --set tls.broker.enabled=true \
    --set tls.bookie.enabled=true \
    --set tls.zookeeper.enabled=true \
    --set tls.function_worker.enabled=true \
    --set components.function_worker=true
}

render_standalone_certificate() {
  local san_mode=$1

  "$helm_bin" template "$release_name" "$chart_dir" \
    --namespace "$namespace" \
    --show-only templates/tls-certs-internal.yaml \
    --set certs.internal_issuer.enabled=true \
    --set standalone.enabled=true \
    --set tls.enabled=true \
    --set tls.common.sanMode="$san_mode"
}

render_renamed_certificates() {
  "$helm_bin" template "$release_name" "$chart_dir" \
    --namespace "$namespace" \
    --show-only templates/tls-certs-internal.yaml \
    --set certs.internal_issuer.enabled=true \
    --set tls.enabled=true \
    --set tls.proxy.enabled=true \
    --set tls.broker.enabled=true \
    --set tls.bookie.enabled=true \
    --set tls.zookeeper.enabled=true \
    --set tls.function_worker.enabled=true \
    --set components.function_worker=true \
    --set tls.common.sanMode=fqdn \
    --set proxy.component=renamed-proxy \
    --set broker.component=renamed-broker \
    --set function_worker.component=renamed-function-worker \
    --set bookkeeper.component=renamed-bookie \
    --set autorecovery.component=renamed-recovery \
    --set toolset.component=renamed-toolset \
    --set zookeeper.component=renamed-zookeeper
}

render_renamed_standalone_certificate() {
  "$helm_bin" template "$release_name" "$chart_dir" \
    --namespace "$namespace" \
    --show-only templates/tls-certs-internal.yaml \
    --set certs.internal_issuer.enabled=true \
    --set standalone.enabled=true \
    --set tls.enabled=true \
    --set tls.common.sanMode=fqdn \
    --set standalone.component=renamed-standalone
}

render_autoscaled_broker_certificate() {
  "$helm_bin" template "$release_name" "$chart_dir" \
    --namespace "$namespace" \
    --show-only templates/tls-certs-internal.yaml \
    --set certs.internal_issuer.enabled=true \
    --set tls.enabled=true \
    --set tls.broker.enabled=true \
    --set tls.common.sanMode=fqdn \
    --set broker.autoscaling.enabled=true \
    --set broker.autoscaling.maxReplicas=5
}

certificate() {
  local certificate_name=$1
  awk -v certificate_name="$certificate_name" '
    { sub(/\r$/, "") }
    /^---$/ { in_certificate = 0 }
    $0 == "  name: \"" certificate_name "\"" { in_certificate = 1 }
    in_certificate { print }
  '
}

assert_contains() {
  local content=$1
  local expected=$2
  local description=$3

  if ! grep -Fq -- "$expected" <<<"$content"; then
    echo "Expected $description to contain: $expected" >&2
    exit 1
  fi
}

assert_not_contains() {
  local content=$1
  local unexpected=$2
  local description=$3

  if grep -Fq -- "$unexpected" <<<"$content"; then
    echo "Expected $description not to contain: $unexpected" >&2
    exit 1
  fi
}

service_name() {
  local component_key=$1
  local component=${2:-$component_key}

  case "$component_key" in
    broker|zookeeper|function-worker)
      printf '%s-pulsar-%s-headless' "$release_name" "$component"
      ;;
    *)
      printf '%s-pulsar-%s' "$release_name" "$component"
      ;;
  esac
}

for san_mode in wildcard fqdn none; do
  rendered=$(render_certificates "$san_mode")
  rendered+=$'\n'
  rendered+=$(render_standalone_certificate "$san_mode")

  for component in "${components[@]}" standalone; do
    certificate_name="$release_name-pulsar-tls-$component"
    certificate_manifest=$(certificate "$certificate_name" <<<"$rendered")
    service="$release_name-pulsar-$component"
    service_fqdn="$service.$namespace.svc.cluster.local"

    assert_contains "$certificate_manifest" "name: \"$certificate_name\"" "$component certificate"
    assert_contains "$certificate_manifest" "\"$service_fqdn\"" "$component $san_mode SANs"
    assert_contains "$certificate_manifest" "\"$service\"" "$component $san_mode SANs"

    case "$san_mode:$component" in
      wildcard:proxy|wildcard:standalone|wildcard:function-worker)
        assert_contains "$certificate_manifest" "\"*.$service.$namespace.svc.cluster.local\"" "$component wildcard SANs"
        ;;
      wildcard:*)
        assert_contains "$certificate_manifest" "\"*.$(service_name "$component").$namespace.svc.cluster.local\"" "$component wildcard SANs"
        ;;
      fqdn:proxy)
        assert_not_contains "$certificate_manifest" "-$component-0." "$component FQDN SANs"
        ;;
      fqdn:standalone)
        assert_not_contains "$certificate_manifest" "-$component-0." "$component FQDN SANs"
        assert_contains "$certificate_manifest" "\"$component.$release_name-pulsar-$component-headless.$namespace.svc.cluster.local\"" "$component FQDN SANs"
        ;;
      fqdn:*)
        assert_contains "$certificate_manifest" "\"$service-0.$(service_name "$component").$namespace.svc.cluster.local\"" "$component FQDN SANs"
        ;;
      none:*)
        assert_not_contains "$certificate_manifest" "\"*." "$component none SANs"
        assert_not_contains "$certificate_manifest" "-$component-0." "$component none SANs"
        ;;
    esac
  done
done

renamed_certificates=$(render_renamed_certificates)
renamed_certificates+=$'\n'
renamed_certificates+=$(render_renamed_standalone_certificate)

for component in "${components[@]}" standalone; do
  certificate_name="$release_name-pulsar-tls-$component"
  certificate_manifest=$(certificate "$certificate_name" <<<"$renamed_certificates")
  renamed_component="renamed-$component"
  renamed_service="$release_name-pulsar-$renamed_component"

  assert_contains "$certificate_manifest" \
    "\"$renamed_service.$namespace.svc.cluster.local\"" \
    "renamed $component service SANs"

  case "$component" in
    proxy|standalone)
      assert_not_contains "$certificate_manifest" "-$renamed_component-0." "renamed $component FQDN SANs"
      ;;
    *)
      assert_contains "$certificate_manifest" \
        "\"$renamed_service-0.$(service_name "$component" "$renamed_component").$namespace.svc.cluster.local\"" \
        "renamed $component FQDN SANs"
      ;;
  esac
done

autoscaled_broker_certificate=$(render_autoscaled_broker_certificate | certificate "$release_name-pulsar-tls-broker")
assert_contains "$autoscaled_broker_certificate" \
  "\"$release_name-pulsar-broker-4.$release_name-pulsar-broker-headless.$namespace.svc.cluster.local\"" \
  "autoscaled broker FQDN SANs"
assert_not_contains "$autoscaled_broker_certificate" \
  "\"$release_name-pulsar-broker-5.$release_name-pulsar-broker-headless.$namespace.svc.cluster.local\"" \
  "autoscaled broker FQDN SANs"

echo "Certificate SAN mode rendering checks passed"