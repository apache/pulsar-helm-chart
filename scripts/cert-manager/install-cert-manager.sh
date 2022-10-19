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

#!/usr/bin/env bash

# If installation fails, the build should fail
set -e

NAMESPACE=cert-manager
NAME=cert-manager
VERSION=v1.7.3

# Install cert-manager CustomResourceDefinition resources
echo "Installing cert-manager CRD resources ..."
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/${VERSION}/cert-manager.crds.yaml

# Create the namespace 
kubectl get ns ${NAMESPACE}
if [ $? == 0 ]; then
    echo "Namespace '${NAMESPACE}' already exists."
else
    echo "Creating namespace '${NAMESPACE}' ..."
    kubectl create namespace ${NAMESPACE}
    echo "Successfully created namespace '${NAMESPACE}'."
fi

# Add the Jetstack Helm repository.
echo "Adding Jetstack Helm repository."
helm repo add jetstack https://charts.jetstack.io
echo "Successfully added Jetstack Helm repository."

# Update local helm chart repository cache.
echo "Updating local helm chart repository cache ..."
helm repo update

echo "Installing cert-manager ${VERSION} to namespace ${NAMESPACE} as '${NAME}' ..."
helm install \
  --namespace ${NAMESPACE} \
  --version ${VERSION} \
  ${NAME} \
  jetstack/cert-manager
echo "Successfully installed cert-manager ${VERSION}."
