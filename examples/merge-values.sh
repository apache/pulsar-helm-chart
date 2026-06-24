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

# Deep-merge multiple Helm values files into a single values file on stdout.
#
# The example values files in this directory are small, focused overrides that
# are meant to be combined. Helm already merges files passed with repeated `-f`
# flags, but it is sometimes useful to produce a single merged file (for review,
# for `helm template`, or to hand to other tooling). This script does that.
#
# Files are merged in order and later files win on conflicting keys (the same
# precedence Helm uses for repeated `-f` flags). The leading Apache license
# header that yq carries over from the first file is stripped so the output
# starts at the first real YAML key.
#
# With --download/-d, the files are fetched by name from the examples directory
# on the master branch instead of being read from the local disk, so the script
# can be run on its own without a checkout.
#
# Requires yq (https://github.com/mikefarah/yq), v4 or later, and curl when
# using --download/-d.
#
# Usage:
#   ./merge-values.sh [--download|-d] <values-file> [<values-file> ...] > merged-values.yaml
#
# Examples:
#   # merge local files
#   ./merge-values.sh values-jwt-asymmetric.yaml values-oxia.yaml values-one-node.yaml
#
#   # download the files from master and merge them
#   ./merge-values.sh -d values-jwt-asymmetric.yaml values-oxia.yaml values-one-node.yaml
#
# The result can be installed with:
#   helm install pulsar apache/pulsar -f merged-values.yaml

BASE_URL="https://raw.githubusercontent.com/apache/pulsar-helm-chart/refs/heads/master/examples"

usage() {
  echo "Usage: $0 [--download|-d] <values-file> [<values-file> ...]" >&2
  echo "Deep-merges the given Helm values files (later files win) and prints the result to stdout." >&2
  echo "With --download/-d, the files are fetched by name from" >&2
  echo "  ${BASE_URL}/" >&2
  echo "instead of being read from the local disk." >&2
}

download=false
files=()
for arg in "$@"; do
  case "$arg" in
    -d|--download) download=true ;;
    -h|--help) usage; exit 0 ;;
    --) ;;
    -*) echo "Error: unknown option: $arg" >&2; usage; exit 1 ;;
    *) files+=("$arg") ;;
  esac
done

if [[ ${#files[@]} -lt 1 ]]; then
  usage
  exit 1
fi

if ! command -v yq >/dev/null 2>&1; then
  echo "Error: yq (https://github.com/mikefarah/yq) is required but was not found on PATH." >&2
  echo "Install it with Homebrew:" >&2
  echo "  brew install yq" >&2
  echo "or download a binary for your platform from:" >&2
  echo "  https://github.com/mikefarah/yq/releases" >&2
  exit 1
fi

if [[ "$download" == "true" ]]; then
  if ! command -v curl >/dev/null 2>&1; then
    echo "Error: curl is required for --download/-d but was not found on PATH." >&2
    exit 1
  fi
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  downloaded=()
  for name in "${files[@]}"; do
    # The files live directly under the examples directory, so only the file
    # name is significant; drop any leading path the caller may have included.
    base="$(basename "$name")"
    dest="${tmpdir}/${base}"
    echo "Downloading ${BASE_URL}/${base} ..." >&2
    if ! curl -fsSL "${BASE_URL}/${base}" -o "$dest"; then
      echo "Error: failed to download ${BASE_URL}/${base}" >&2
      exit 1
    fi
    downloaded+=("$dest")
  done
  files=("${downloaded[@]}")
else
  for f in "${files[@]}"; do
    if [[ ! -f "$f" ]]; then
      echo "Error: values file not found: $f" >&2
      echo "(use --download/-d to fetch it by name from the master branch instead)" >&2
      exit 1
    fi
  done
fi

# `*` is yq's deep-merge operator; ireduce folds it across every input document.
# The awk step drops the leading comment/blank lines (the license header) and
# prints everything from the first real key onward.
yq eval-all '. as $item ireduce ({}; . * $item)' "${files[@]}" \
  | awk 'NF && $1 !~ /^#/ {seen=1} seen'
