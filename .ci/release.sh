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


BINDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
CHARTS_HOME="$(cd "${BINDIR}/.." && pwd)"
CHARTS_PKGS=${CHARTS_HOME}/.chart-packages
CHARTS_INDEX=${CHARTS_HOME}/.chart-index
CHARTS_REPO=${CHARTS_REPO:-"https://pulsar.apache.org/charts/"}
OWNER=${OWNER:-apache}
REPO=${REPO:-pulsar-helm-chart}
PUBLISH_CHARTS=${PUBLISH_CHARTS:-"false"}
PULSAR_SITE_REPO_SLUG=${PULSAR_SITE_REPO_SLUG:-"apache/pulsar-site"}
PULSAR_SITE_BRANCH=${PULSAR_SITE_BRANCH:-"asf-site-next"}

# hack/common.sh need this variable to be set
PULSAR_CHART_HOME=${CHARTS_HOME}

source ${CHARTS_HOME}/hack/common.sh
source ${CHARTS_HOME}/.ci/git.sh

# allow overwriting cr binary
CR="docker run -v ${CHARTS_HOME}:/cr quay.io/helmpack/chart-releaser:v${CR_VERSION}"

function release::ensure_dir() {
    local dir=$1
    if [[ -d ${dir} ]]; then
        rm -rf ${dir}
    fi
    mkdir -p ${dir}
}

function release::find_changed_charts() {
    local charts_dir=$1
    echo $(git diff --find-renames --name-only "$latest_tag_rev" -- ${charts_dir} | cut -d '/' -f 2 | uniq)
}

function release::package_chart() {
    local chart=$1
    echo "Packaging chart '$chart'..."
    helm package ${CHARTS_HOME}/charts/$chart --destination ${CHARTS_PKGS}
}

function release::upload_packages() {
    ${CR} upload --owner ${OWNER} --git-repo ${REPO} -t ${GITHUB_TOKEN} --package-path /cr/.chart-packages
}

function release::update_chart_index() {
    ${CR} index -o ${OWNER} -r ${REPO} -t "${GITHUB_TOKEN}" -c ${CHARTS_REPO} --index-path /cr/.chart-index --package-path /cr/.chart-packages
}

function release::git_setup() {
  git config --global user.email "dev@pulsar.apache.org"
  git config --global user.name "Apache Pulsar Team"
}

function release::publish_charts() {
    release::git_setup
    git clone -b "$PULSAR_SITE_BRANCH" --depth 1 "https://${GITHUB_TOKEN}@github.com/${PULSAR_SITE_REPO_SLUG}" pulsar-site
    cd pulsar-site
    mkdir -p content/charts
    cp --force ${CHARTS_INDEX}/index.yaml content/charts/index.yaml
    git add content/charts/index.yaml
    ls content/charts
    git commit --message="Publish new charts to ${CHARTS_REPO}" --signoff
    if [[ "x${PUBLISH_CHARTS}" == "xtrue" ]]; then
      git push --set-upstream origin "$PULSAR_SITE_BRANCH"
    else
      echo "Skipping publishing charts"
    fi
}

# install cr
# hack::ensure_cr
docker pull quay.io/helmpack/chart-releaser:v${CR_VERSION}

latest_tag=$(git::find_latest_tag)
echo "Latest tag: $latest_tag"

latest_tag_rev=$(git::get_revision "$latest_tag")
echo "$latest_tag_rev $latest_tag (latest tag)"

head_rev=$(git::get_revision HEAD)
echo "$head_rev HEAD"

if [[ "$latest_tag_rev" == "$head_rev" ]]; then
    echo "Do nothing. Exiting ..."
    exit
fi

release::ensure_dir ${CHARTS_PKGS}
release::ensure_dir ${CHARTS_INDEX}

for chart in $(release::find_changed_charts charts); do
    release::package_chart ${chart}
done

release::upload_packages
release::update_chart_index
release::publish_charts
