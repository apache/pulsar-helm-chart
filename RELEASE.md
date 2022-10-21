<!--
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
-->

This document details the steps for releasing the Apache Pulsar Helm Chart.

# Prepare the Apache Pulsar Helm Chart Release Candidate

## Prerequisites

- Helm version >= 3.0.2
- Helm gpg plugin (one option: https://github.com/technosophos/helm-gpg)

## Build Release Notes

Before creating the RC, you need to build and commit the release notes for the release.

## Build RC artifacts

The Release Candidate artifacts we vote upon should be the exact ones we vote against,
without any modification than renaming – i.e. the contents of the files must be
the same between voted release candidate and final release.
Because of this the version in the built artifacts that will become the
official Apache releases must not include the rcN suffix.

- Set environment variables

    ```shell
    # Set Version
    export VERSION=1.0.1-candidate-1
    export VERSION_WITHOUT_RC=${VERSION%-candidate-*}

    # Clone and set PULSAR_REPO_ROOT
    git clone https://github.com/apache/pulsar-helm-chart.git pulsar
    cd pulsar-helm-chart
    export PULSAR_REPO_ROOT=$(pwd)
    ```

- We currently release Helm Chart from `master` branch:

    ```shell
    git checkout master
    ```

- Clean the checkout: the sdist step below will

    ```shell
    git clean -fdX .
    ```

- Update Helm Chart version in `Chart.yaml`, example: `version: 1.0.0` (without
  the RC tag). Verify that the `appVersion` matches the `values.yaml` versions for Pulsar components.

- Add and commit the version change.

    ```shell
    git add charts/pulsar/Chart.yaml
    git commit -m "Chart: Bump version to $VERSION_WITHOUT_RC"
    ```

  Note: You will tag this commit, you do not need to open a PR for it.

- Tag your release

    ```shell
    git tag -s pulsar-${VERSION} -m "Apache Pulsar Helm Chart $VERSION"
    ```

- Tarball the repo

    NOTE: Make sure your checkout is clean at this stage - any untracked or changed files will otherwise be included
     in the file produced.

    ```shell
    git archive --format=tar.gz pulsar-${VERSION} --prefix=pulsar-chart-${VERSION_WITHOUT_RC}/ \
        -o pulsar-chart-${VERSION_WITHOUT_RC}-source.tar.gz .
    ```

- Generate chart binary


    ```shell
    helm package charts/pulsar --dependency-update
    ```

- Sign the chart binary

    In the following command, replace the email address with your email address or your KEY ID
    so GPG uses the right key to sign the chart.
    (If you have not generated a key yet, generate it by following instructions on
    http://www.apache.org/dev/openpgp.html#key-gen-generate-key)

    ```shell
    helm gpg sign -u <apache_id>@apache.org pulsar-${VERSION_WITHOUT_RC}.tgz
    ```

    Warning: you need the `helm gpg` plugin to sign the chart. It can be found at: https://github.com/technosophos/helm-gpg

    This should also generate a provenance file (Example: `pulsar-1.0.0.tgz.prov`) as described in
    https://helm.sh/docs/topics/provenance/, which can be used to verify integrity of the Helm chart.

    Verify the signed chart (with example output shown):

    ```shell
    $ helm gpg verify pulsar-${VERSION_WITHOUT_RC}.tgz
    gpg: Signature made Thu Oct 20 16:36:24 2022 CDT
    gpg:                using RSA key BD4291E509D771B79E7BD1F5C5724B3F5588C4EB
    gpg:                issuer "mmarshall@apache.org"
    gpg: Good signature from "Michael Marshall <mmarshall@apache.org>" [ultimate]
    plugin: Chart SHA verified. sha256:deb035dcb765b1989ed726eabe3d7d89529df05658c8eec6cdd4dc213fa0513e
    ```

- Generate SHA512/ASC

    ```shell
    ${PULSAR_REPO_ROOT}/scripts/sign.sh pulsar-chart-${VERSION_WITHOUT_RC}-source.tar.gz
    ${PULSAR_REPO_ROOT}/scripts/sign.sh pulsar-${VERSION_WITHOUT_RC}.tgz
    ```

- Move the artifacts to ASF dev dist repo, generate convenience `index.yaml` & publish them

  ```shell
  # First clone the repo
  svn checkout https://dist.apache.org/repos/dist/dev/pulsar pulsar-dist-dev

  # Create new folder for the release
  cd pulsar-dist-dev/helm-chart
  svn mkdir ${VERSION}

  # Move the artifacts to svn folder
  mv ${PULSAR_REPO_ROOT}/pulsar-${VERSION_WITHOUT_RC}.tgz* ${VERSION}/
  mv ${PULSAR_REPO_ROOT}/pulsar-chart-${VERSION_WITHOUT_RC}-source.tar.gz* ${VERSION}/
  cd ${VERSION}

  ###### Generate index.yaml file - Start
  # Download the latest index.yaml on Pulsar Website
  curl https://dist.apache.org/repos/dist/release/pulsar/helm-chart/index.yaml --output index.yaml

  # Replace the URLs from "https://downloads.apache.org" to "https://archive.apache.org"
  # as the downloads.apache.org only contains latest releases.
  sed -i 's|https://downloads.apache.org/pulsar/helm-chart/|https://archive.apache.org/dist/pulsar/helm-chart/|' index.yaml

  # Generate / Merge the new version with existing index.yaml
  helm repo index --merge ./index.yaml . --url "https://dist.apache.org/repos/dist/dev/pulsar/helm-chart/${VERSION}"

  ###### Generate index.yaml file - End

  # Commit the artifacts
  svn add *
  svn commit -m "Add artifacts for Helm Chart ${VERSION}"
  ```

- Remove old Helm Chart versions from the dev repo

  ```shell
  cd ..
  export PREVIOUS_VERSION=1.0.0-candidate-1
  svn rm ${PREVIOUS_VERSION}
  svn commit -m "Remove old Helm Chart release: ${PREVIOUS_VERSION}"
  ```

- Push Tag for the release candidate

  ```shell
  cd ${PULSAR_REPO_ROOT}
  git push upstream tag pulsar-${VERSION}
  ```

## Prepare Vote email on the Apache Pulsar release candidate

- Send out a vote to the dev@pulsar.apache.org mailing list:

Subject:

```shell
cat <<EOF
[VOTE] Release Apache Pulsar Helm Chart ${VERSION_WITHOUT_RC} based on ${VERSION}
EOF
```

Body:

```shell
cat <<EOF
Hello Apache Pulsar Community,

This is a call for the vote to release Helm Chart version ${VERSION_WITHOUT_RC}.

The release candidate is available at:
https://dist.apache.org/repos/dist/dev/pulsar/helm-chart/$VERSION/

pulsar-chart-${VERSION_WITHOUT_RC}-source.tar.gz - is the "main source release".
pulsar-${VERSION_WITHOUT_RC}.tgz - is the binary Helm Chart release.

Public keys are available at: https://www.apache.org/dist/pulsar/KEYS

For convenience "index.yaml" has been uploaded (though excluded from voting), so you can also run the below commands.

helm repo add apache-pulsar-dist-dev https://dist.apache.org/repos/dist/dev/pulsar/helm-chart/$VERSION/
helm repo update
helm install pulsar apache-pulsar-dist-dev/pulsar

pulsar-${VERSION_WITHOUT_RC}.tgz.prov - is also uploaded for verifying Chart Integrity, though it is not strictly required for releasing the artifact based on ASF Guidelines. 

You can optionally verify this file using this helm plugin https://github.com/technosophos/helm-gpg, or by using helm --verify (https://helm.sh/docs/helm/helm_verify/).

helm gpg verify pulsar-${VERSION_WITHOUT_RC}.tgz

The vote will be open for at least 72 hours.

Only votes from PMC members are binding, but members of the community are
encouraged to test the release and vote with "(non-binding)".

For license checks, the .rat-excludes files is included, so you can run the following to verify licenses (just update $PATH_TO_RAT):

tar -xvf pulsar-chart-${VERSION_WITHOUT_RC}-source.tar.gz
cd pulsar-chart-${VERSION_WITHOUT_RC}
java -jar $PATH_TO_RAT/apache-rat-0.15/apache-rat-0.15.jar . -E .rat-excludes

Please note that the version number excludes the \`-candidate-X\` string, so it's now
simply ${VERSION_WITHOUT_RC}. This will allow us to rename the artifact without modifying
the artifact checksums when we actually release it.

Thanks,
<your name>
EOF
```

Note, you need to update the `helm gpg verify` output and verify the end of the voting period in the body.

## Note about `helm gpg` vs `helm --verify`

Helm ships with a gpg verification tool, but it appears not to work with the currently used format for our KEYS file.

# Verify the release candidate by the PMC

The PMC should verify the releases in order to make sure the release is following the
[Apache Legal Release Policy](http://www.apache.org/legal/release-policy.html).

At least 3 (+1) votes from PMC members should be recorded in accordance to
[Votes on Package Releases](https://www.apache.org/foundation/voting.html#ReleaseVotes)

The legal checks include:

* checking if the packages are present in the right dist folder on svn
* verifying if all the sources have correct licences
* verifying if release manager signed the releases with the right key
* verifying if all the checksums are valid for the release

## SVN check

The files should be present in the sub-folder of
[Pulsar dist](https://dist.apache.org/repos/dist/dev/pulsar/)

The following files should be present (7 files):

* `pulsar-chart-${VERSION_WITHOUT_RC}-source.tar.gz` + .asc + .sha512
* `pulsar-${VERSION_WITHOUT_RC}.tgz` + .asc + .sha512
* `pulsar-${VERSION_WITHOUT_RC}.tgz.prov`

As a PMC member you should be able to clone the SVN repository:

```shell
svn co https://dist.apache.org/repos/dist/dev/pulsar
```

Or update it if you already checked it out:

```shell
svn update .
```

## Licence check

This can be done with the Apache RAT tool.

* Download the latest jar from https://creadur.apache.org/rat/download_rat.cgi (unpack the binary,
  the jar is inside)
* Unpack the release source archive (the `<package + version>-source.tar.gz` file) to a folder
* Enter the sources folder run the check

```shell
java -jar $PATH_TO_RAT/apache-rat-0.15/apache-rat-0.15.jar pulsar-chart-${VERSION_WITHOUT_RC} -E .rat-excludes
```

where `.rat-excludes` is the file in the root of git repo.

## Signature check

Make sure you have imported into your GPG the PGP key of the person signing the release. You can find the valid keys in
[KEYS](https://dist.apache.org/repos/dist/release/pulsar/KEYS).

You can import the whole KEYS file:

```shell script
gpg --import KEYS
```

You can also import the keys individually from a keyserver. The below one uses a key and
retrieves it from the default GPG keyserver
[OpenPGP.org](https://keys.openpgp.org):

```shell script
gpg --keyserver keys.openpgp.org --receive-keys <some_key>
```

You should choose to import the key when asked.

Note that by being default, the OpenPGP server tends to be overloaded often and might respond with
errors or timeouts. Many of the release managers also uploaded their keys to the
[GNUPG.net](https://keys.gnupg.net) keyserver, and you can retrieve it from there.

```shell script
gpg --keyserver keys.gnupg.net --receive-keys <some_key>
```

Once you have the keys, the signatures can be verified by running this:

```shell script
for i in *.asc
do
   echo -e "Checking $i\n"; gpg --verify $i
done
```

This should produce results similar to the below. The "Good signature from ..." is indication
that the signatures are correct. Do not worry about the "not certified with a trusted signature"
warning. Most of the certificates used by release managers are self-signed, and that's why you get this
warning. By importing the key either from the server in the previous step or from the
[KEYS](https://dist.apache.org/repos/dist/release/pulsar/KEYS) page, you know that
this is a valid key already.

## SHA512 sum check

Run this:

```shell
for i in *.sha512
do
    echo "Checking $i"; shasum -a 512 `basename $i .sha512 ` | diff - $i
done
```

You should get output similar to:

```
Checking pulsar-1.0.0.tgz.sha512
Checking pulsar-chart-1.0.0-source.tar.gz.sha512
```

# Verify release candidates by Contributors

Contributors can run below commands to test the Helm Chart

```shell
helm repo add apache-pulsar-dist-dev https://dist.apache.org/repos/dist/dev/pulsar/helm-chart/1.0.1-candidate-1/
helm repo update
helm install pulsar apache-pulsar-dist-dev/pulsar
```

You can then perform any other verifications to check that it works as you expected by
upgrading the Chart or installing by overriding default of `values.yaml`.

# Publish the final release

## Summarize the voting for the release

Once the vote has been passed, you will need to send a result vote to [dev@pulsar.apache.org](mailto:dev@pulsar.apache.org):

Subject:

```shell
cat <<EOF
[RESULT][VOTE] Release Apache Pulsar Helm Chart ${VERSION_WITHOUT_RC} based on ${VERSION}
EOF
```

Message:

```shell
cat <<EOF
Hello all,

The vote to release Apache Pulsar Helm Chart version ${VERSION_WITHOUT_RC} based on ${VERSION} is now closed.

The vote PASSED with X binding "+1", Y non-binding "+1" and 0 "-1" votes:

"+1" Binding votes:

  - <name>

"+1" Non-Binding votes:

  - <name>

I'll continue with the release process and the release announcement will follow shortly.

Thanks,
<your name>
EOF
```

## Publish release to SVN

You need to migrate the RC artifacts that passed to this repository:
https://dist.apache.org/repos/dist/release/pulsar/helm-chart/
(The migration should include renaming the files so that they no longer have the RC number in their filenames.)

The best way of doing this is to svn cp between the two repos (this avoids having to upload
the binaries again, and gives a clearer history in the svn commit logs):

```shell
# First clone the repo
export RC=$(git describe)
export VERSION=${RC%-candidate-*}
svn checkout https://dist.apache.org/repos/dist/release/pulsar pulsar-dist-release

# Create new folder for the release
cd pulsar-dist-release/helm-chart
export PULSAR_SVN_RELEASE_HELM=$(pwd)
svn mkdir ${VERSION}
cd ${VERSION}

# Move the artifacts to svn folder & commit (don't copy or copy & remove - index.yaml)
for f in ../../../pulsar-dist-dev/helm-chart/$RC/*; do svn cp $f ${$(basename $f)/}; done
svn rm index.yaml
svn commit -m "Release Pulsar Helm Chart ${VERSION} from ${RC}"
```

Verify that the packages appear in [Pulsar Helm Chart](https://dist.apache.org/repos/dist/release/pulsar/helm-chart/).

Then, run the following command from within `pulsar-dist-release/helm-chart` in the svn repo.

```shell
sed -i 's|https://downloads.apache.org/pulsar/helm-chart/|https://archive.apache.org/dist/pulsar/helm-chart/|' index.yaml
helm repo index ${VERSION}/ --merge ./index.yaml --url "https://dist.apache.org/repos/dist/dev/pulsar/helm-chart/${VERSION}"
```

Verify that the updated `index.yaml` file has the most recent version. Then run:

```shell
svn add index.yaml
svn commit -m "Adding Pulsar Helm Chart ${VERSION} to index.yaml"
```

## Publish release tag

Create and push the release tag:

```shell
cd "${PULSAR_REPO_ROOT}"
git checkout pulsar-${RC}
git tag -s pulsar-${VERSION} -m "Apache Pulsar Helm Chart ${VERSION}"
git push upstream pulsar-${VERSION}
```

## Notify developers of release

- Notify users@pulsar.apache.org (cc'ing dev@pulsar.apache.org) that
the artifacts have been published:

Subject:

```shell
cat <<EOF
[ANNOUNCE] Apache Pulsar Helm Chart version ${VERSION} Released
EOF
```

Body:

```shell
cat <<EOF
Dear Pulsar community,

I am pleased to announce that we have released Apache Pulsar Helm chart $VERSION 🎉 🎊

The source release, as well as the "binary" Helm Chart release, are available:

Official Sources: https://pulsar.apache.org/download/
ArtifactHub: https://artifacthub.io/packages/helm/apache/pulsar/$VERSION
Docs: https://pulsar.apache.org/docs/helm-overview
Release Notes: https://pulsar.apache.org/docs/helm-chart/$VERSION/release_notes.html

Thanks to all the contributors who made this possible.

Regards,

The Apache Pulsar Team
EOF
```

Send the same email to announce@apache.org, except change the opening line to `Dear community,`.
It is more reliable to send it via the web ui at https://lists.apache.org/list.html?announce@apache.org
(press "c" to compose a new thread)

## Create release on GitHub

Create a new release on GitHub with the release notes and assets from the release svn.

## Close the milestone

Close the milestone on GitHub. Create the next one if it hasn't been already.

## Announce the release on the community slack

Post this in the #announce channel:

```shell
cat <<EOF
We've just released Apache Pulsar Helm Chart ${VERSION} 🎉

Official Sources: https://pulsar.apache.org/download/
ArtifactHub: https://artifacthub.io/packages/helm/apache/pulsar/$VERSION
Docs: https://pulsar.apache.org/docs/helm-overview
Release Notes: https://pulsar.apache.org/docs/helm-chart/$VERSION/release_notes.html

Thanks to all the contributors who made this possible.
EOF
```

## Bump chart version in Chart.yaml

Bump the chart version to the next version in `charts/pulsar/Chart.yaml` in master.

## Remove old releases

We should keep the old version a little longer than a day. We updated the `index.yaml` earlier so that it points to the
older releases. The short delay will help avoid errors for users who haven't run ``helm repo update`` to get the latest
`index.yaml`.

It is probably ok if we leave last 2 versions on release svn repo too.

```shell
# https://www.apache.org/legal/release-policy.html#when-to-archive
cd pulsar-dist-release/helm-chart
export PREVIOUS_VERSION=1.0.0
svn rm ${PREVIOUS_VERSION}
svn commit -m "Remove old Helm Chart release: ${PREVIOUS_VERSION}"
```