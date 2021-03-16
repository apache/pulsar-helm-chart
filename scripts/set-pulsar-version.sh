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

# this script is used for setting default pulsar image version in the charts/pulsar/values.yaml
# usage:
#   set-pulsar-version.sh ${old_version} ${new_version}
# example: update the pulsar version from 2.7.0 to 2.7.1
#   set-pulsar-version.sh 2.7.0 2.7.1

OLD_VERSION=${1}
NEW_VERSION=${2}

if [[ "" == ${OLD_VERSION} || "" == ${NEW_VERSION} ]]; then
  echo "You need to provide the old_version and new_version"
  exit 1
fi

sed -i ""  "s/${OLD_VERSION}/${NEW_VERSION}/g" charts/pulsar/values.yaml
sed -i ""  "s/${OLD_VERSION}/${NEW_VERSION}/g" charts/pulsar/Chart.yaml
