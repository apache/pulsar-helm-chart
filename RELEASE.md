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

- Helm version >= 3.12.0
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
    export VERSION_RC=3.0.0-candidate-1
    export VERSION_WITHOUT_RC=${VERSION_RC%-candidate-*}
    # set your ASF user id
    export APACHE_USER=<your ASF userid>
    ```

- Clone clean repository and set PULSAR_REPO_ROOT

    ```shell
    git clone https://github.com/apache/pulsar-helm-chart.git
    cd pulsar-helm-chart
    export PULSAR_REPO_ROOT=$(pwd)
    ```

- Alternatively (not recommended), go to your already checked out pulsar-helm-chart directory and ensure that it's clean

    ```shell
    git checkout master
    git fetch origin
    git reset --hard origin/master
    # clean the checkout
    git clean -fdX .
    export PULSAR_REPO_ROOT=$(pwd)
    ```

- Update Helm Chart version in `Chart.yaml`, example: `version: 1.0.0` (without
  the RC tag). Verify that the `appVersion` matches the `values.yaml` versions for Pulsar components.

    ```shell
    yq -i '.version=strenv(VERSION_WITHOUT_RC)' charts/pulsar/Chart.yaml
    ```

- Add and commit the version change.

    ```shell
    git add charts/pulsar/Chart.yaml
    git commit -m "Chart: Bump version to $VERSION_WITHOUT_RC"
    git push origin master
    ```

  Note: You will tag this commit, you do not need to open a PR for it.

- Tag your release

    ```shell
    git tag -s pulsar-${VERSION_RC} -m "Apache Pulsar Helm Chart $VERSION_RC"
    ```

- Tarball the repo

    NOTE: Make sure your checkout is clean at this stage - any untracked or changed files will otherwise be included
     in the file produced.

    ```shell
    git archive --format=tar.gz pulsar-${VERSION_RC} --prefix=pulsar-chart-${VERSION_WITHOUT_RC}/ \
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
    helm gpg sign -u $APACHE_USER@apache.org pulsar-${VERSION_WITHOUT_RC}.tgz
    ```

    Warning: you need the `helm gpg` plugin to sign the chart. It can be found at: https://github.com/technosophos/helm-gpg

    This should also generate a provenance file (Example: `pulsar-1.0.0.tgz.prov`) as described in
    https://helm.sh/docs/topics/provenance/, which can be used to verify integrity of the Helm chart.

    Verify the signed chart:

    ```shell
    helm gpg verify pulsar-${VERSION_WITHOUT_RC}.tgz
    ```

    Example output:
    ```
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
  # Create new folder for the release
  svn mkdir --username $APACHE_USER -m "Add directory for pulsar-helm-chart $VERSION_RC release" https://dist.apache.org/repos/dist/dev/pulsar/helm-chart/$VERSION_RC
  # checkout the directory
  svn co --username $APACHE_USER https://dist.apache.org/repos/dist/dev/pulsar/helm-chart/$VERSION_RC helm-chart-$VERSION_RC

  # Move the artifacts to svn folder
  mv ${PULSAR_REPO_ROOT}/pulsar-${VERSION_WITHOUT_RC}.tgz* helm-chart-${VERSION_RC}/
  mv ${PULSAR_REPO_ROOT}/pulsar-chart-${VERSION_WITHOUT_RC}-source.tar.gz* helm-chart-${VERSION_RC}/
  cd helm-chart-${VERSION_RC}/

  ###### Generate index.yaml file - Start
  # Download the latest index.yaml on Pulsar Website
  curl https://pulsar.apache.org/charts/index.yaml --output index.yaml

  # Replace the URLs from "https://downloads.apache.org" to "https://archive.apache.org"
  # as the downloads.apache.org only contains latest releases.
  sed -i 's|https://downloads.apache.org/pulsar/helm-chart/|https://archive.apache.org/dist/pulsar/helm-chart/|' index.yaml

  # Generate / Merge the new version with existing index.yaml
  helm repo index --merge ./index.yaml . --url "https://dist.apache.org/repos/dist/dev/pulsar/helm-chart/${VERSION_RC}"

  ###### Generate index.yaml file - End

  # Commit the artifacts
  svn add *
  svn commit -m "Add artifacts for Helm Chart ${VERSION_RC}"
  ```

- Remove old Helm Chart versions from the dev repo 

  First check if this is required by viewing the versions available at https://dist.apache.org/repos/dist/dev/pulsar/helm-chart

  ```shell
  export PREVIOUS_VERSION_RC=3.0.0-candidate-1
  svn rm --username $APACHE_USER -m "Remove old Helm Chart release: ${PREVIOUS_VERSION_RC}" https://dist.apache.org/repos/dist/dev/pulsar/helm-chart/${PREVIOUS_VERSION_RC}
  ```

- Push Tag for the release candidate

  ```shell
  cd ${PULSAR_REPO_ROOT}
  git push origin tag pulsar-${VERSION_RC}
  ```

## Create release notes for the release candidate in GitHub UI

```shell 
# open this URL and create release notes by clicking "Create release from tag"
echo https://github.com/apache/pulsar-helm-chart/releases/tag/pulsar-${VERSION_RC}
```

1. Open the above URL in a browser and create release notes by clicking "Create release from tag".
2. Find "Previous tag: auto" in the UI above the text box and choose the previous release there.
3. Click "Generate release notes".
4. Review the generated release notes.
5. Select "Set as a pre-release"
6. Click "Publish release".  

## Prepare Vote email on the Apache Pulsar release candidate


- Send out a vote to the dev@pulsar.apache.org mailing list:

> [!TIP]
> The template output will get copied to the clipboard using pbpaste. On Linux, you can install xsel and add `alias pbcopy='xsel --clipboard --input'` to the shell. 

Subject:

```shell
tee >(pbcopy) <<EOF
[VOTE] Release Apache Pulsar Helm Chart ${VERSION_WITHOUT_RC} based on ${VERSION_RC}
EOF
```

Body:

```shell
tee >(pbcopy) <<EOF
Hello Apache Pulsar Community,

This is a call for the vote to release the Apache Pulsar Helm Chart version ${VERSION_WITHOUT_RC}.

Release notes for $VERSION_RC:
https://github.com/apache/pulsar-helm-chart/releases/tag/pulsar-$VERSION_RC

The release candidate is available at:
https://dist.apache.org/repos/dist/dev/pulsar/helm-chart/$VERSION_RC/

pulsar-chart-${VERSION_WITHOUT_RC}-source.tar.gz - is the "main source release".
pulsar-${VERSION_WITHOUT_RC}.tgz - is the binary Helm Chart release.

Public keys are available at: https://www.apache.org/dist/pulsar/KEYS

For convenience "index.yaml" has been uploaded (though excluded from voting), so you can also run the below commands.

helm repo add --force-update apache-pulsar-dist-dev https://dist.apache.org/repos/dist/dev/pulsar/helm-chart/$VERSION_RC/
helm repo update
helm install pulsar apache-pulsar-dist-dev/pulsar --version ${VERSION_WITHOUT_RC} --set affinity.anti_affinity=false

pulsar-${VERSION_WITHOUT_RC}.tgz.prov - is also uploaded for verifying Chart Integrity, though it is not strictly required for releasing the artifact based on ASF Guidelines. 

You can optionally verify this file using this helm plugin https://github.com/technosophos/helm-gpg, or by using helm --verify (https://helm.sh/docs/helm/helm_verify/).

helm fetch --prov apache-pulsar-dist-dev/pulsar
helm plugin install https://github.com/technosophos/helm-gpg
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
[Pulsar dist](https://dist.apache.org/repos/dist/dev/pulsar/helm-chart)

The following files should be present (7 files):

* `pulsar-chart-${VERSION_WITHOUT_RC}-source.tar.gz` + .asc + .sha512
* `pulsar-${VERSION_WITHOUT_RC}.tgz` + .asc + .sha512
* `pulsar-${VERSION_WITHOUT_RC}.tgz.prov`

As a PMC member you should be able to clone the SVN repository:

```shell
svn co https://dist.apache.org/repos/dist/dev/pulsar/helm-chart
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
export VERSION_RC=3.0.0-candidate-1
export VERSION_WITHOUT_RC=${VERSION_RC%-candidate-*}
helm repo add --force-update apache-pulsar-dist-dev https://dist.apache.org/repos/dist/dev/pulsar/helm-chart/$VERSION_RC/
helm repo update
helm install pulsar apache-pulsar-dist-dev/pulsar --version ${VERSION_WITHOUT_RC} --set affinity.anti_affinity=false
```

You can then perform any other verifications to check that it works as you expected by
upgrading the Chart or installing by overriding default of `values.yaml`.

# Publish the final release

## Summarize the voting for the release

Once the vote has been passed, you will need to send a result vote to [dev@pulsar.apache.org](mailto:dev@pulsar.apache.org):

Subject:

```shell
tee >(pbcopy) <<EOF
[RESULT][VOTE] Release Apache Pulsar Helm Chart ${VERSION_WITHOUT_RC} based on ${VERSION_RC}
EOF
```

Message:

```shell
tee >(pbcopy) <<EOF
Hello all,

The vote to release Apache Pulsar Helm Chart version ${VERSION_WITHOUT_RC} based on ${VERSION_RC} is now closed.

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

Set environment variables
```shell
export VERSION_RC=3.0.0-candidate-1
export VERSION_WITHOUT_RC=${VERSION_RC%-candidate-*}
export APACHE_USER=<your ASF userid>
```

Migrating the approved RC artifacts to the release directory:
https://dist.apache.org/repos/dist/release/pulsar/helm-chart/

svn commands for handling this:

```shell
svn rm --username $APACHE_USER -m "Remove temporary index.yaml file" https://dist.apache.org/repos/dist/dev/pulsar/helm-chart/${VERSION_RC}/index.yaml
svn move --username $APACHE_USER -m "Release Pulsar Helm Chart ${VERSION_WITHOUT_RC} from ${VERSION_RC}" \
  https://dist.apache.org/repos/dist/dev/pulsar/helm-chart/${VERSION_RC} \
  https://dist.apache.org/repos/dist/release/pulsar/helm-chart/${VERSION_WITHOUT_RC}
```

Verify that the packages appear in [Pulsar Helm Chart](https://dist.apache.org/repos/dist/release/pulsar/helm-chart/).

## Publish release tag

Create and push the release tag:

```shell
cd "${PULSAR_REPO_ROOT}"
git checkout pulsar-${VERSION_RC}
git tag -s pulsar-${VERSION_WITHOUT_RC} -m "Apache Pulsar Helm Chart ${VERSION_WITHOUT_RC}"
git push origin pulsar-${VERSION_WITHOUT_RC}
```

## Update index.yaml

The `index.yaml` file is the way helm users discover the binaries for the helm distribution. We currently host the
file at `pulsar.apache.org/charts/index.yaml`.

Then, run the following command from within `github.com/apache/pulsar-site` in the git repo.

```shell
# checkout pulsar-site
git clone https://github.com/apache/pulsar-site
cd pulsar-site
```

```shell
# Run on a branch based on main branch
cd static/charts
# need the chart file temporarily to update the index
wget https://downloads.apache.org/pulsar/helm-chart/${VERSION_WITHOUT_RC}/pulsar-${VERSION_WITHOUT_RC}.tgz
# store the license header temporarily
head -n 17 index.yaml > license_header.txt
# update the index
helm repo index --merge ./index.yaml . --url "https://downloads.apache.org/pulsar/helm-chart/${VERSION_WITHOUT_RC}"
# restore the license header
mv index.yaml index.yaml.new
cat license_header.txt index.yaml.new > index.yaml
rm license_header.txt index.yaml.new
# remove the temp file
rm pulsar-${VERSION_WITHOUT_RC}.tgz
```

Verify that the updated `index.yaml` file has the most recent version. Then run:

```shell
git add index.yaml
git commit -m "Adding Pulsar Helm Chart ${VERSION_WITHOUT_RC} to index.yaml"
```

Then open a PR.

## Create release notes for the tag in GitHub UI

```shell 
# open this URL and create release notes by clicking "Create release from tag"
echo https://github.com/apache/pulsar-helm-chart/releases/tag/pulsar-${VERSION_WITHOUT_RC}
```

1. Open the above URL in a browser and create release notes by clicking "Create release from tag".
2. Find "Previous tag: auto" in the UI above the text box and choose the previous release there.
3. Click "Generate release notes".
4. Review the generated release notes.
5. Click "Publish release".


## Notify developers of release

Once the `index.yaml` is live on the website, it is time to announce the release.

- Notify users@pulsar.apache.org (cc'ing dev@pulsar.apache.org) that
the artifacts have been published:

Subject:

```shell
tee >(pbcopy) <<EOF
[ANNOUNCE] Apache Pulsar Helm Chart version ${VERSION_WITHOUT_RC} Released
EOF
```

Body:

```shell
tee >(pbcopy) <<EOF
Dear community,

The Apache Pulsar team is pleased to announce the release of the Apache
Pulsar Helm Chart $VERSION_WITHOUT_RC.

The official source release, as well as the binary Helm Chart release,
are available at
https://downloads.apache.org/pulsar/helm-chart/$VERSION_WITHOUT_RC/.

The helm chart index at https://pulsar.apache.org/charts/ has been
updated and the release is also available directly via helm.

Release Notes:
https://github.com/apache/pulsar-helm-chart/releases/tag/pulsar-$VERSION_WITHOUT_RC
Docs: https://github.com/apache/pulsar-helm-chart#readme and https://pulsar.apache.org/docs/helm-overview
ArtifactHub: https://artifacthub.io/packages/helm/apache/pulsar/$VERSION_WITHOUT_RC

Thanks to all the contributors who made this possible.

Regards,

The Apache Pulsar Team
EOF
```


Send the same email to announce@apache.org.
It is more reliable to send it via the web ui at https://lists.apache.org/list.html?announce@apache.org
(press "c" to compose a new thread).

## Create release on GitHub

Create a new release on GitHub with the release notes and assets from the release svn.

## Close the milestone

Close the milestone on GitHub. Create the next one if it hasn't been already.

## Announce the release on the community slack

Post this in the #announce channel:

```shell
tee >(pbcopy) <<EOF
We've just released Apache Pulsar Helm Chart ${VERSION_WITHOUT_RC} 🎉

The official source release, as well as the binary Helm Chart release,
are available at
https://downloads.apache.org/pulsar/helm-chart/$VERSION_WITHOUT_RC/.

The helm chart index at https://pulsar.apache.org/charts/ has been
updated and the release is also available directly via helm.

Release Notes:
https://github.com/apache/pulsar-helm-chart/releases/tag/pulsar-$VERSION_WITHOUT_RC
Docs: https://github.com/apache/pulsar-helm-chart#readme and https://pulsar.apache.org/docs/helm-overview
ArtifactHub: https://artifacthub.io/packages/helm/apache/pulsar/$VERSION_WITHOUT_RC

Thanks to all the contributors who made this possible.
EOF
```

## Maintaining svn https://dist.apache.org/repos/dist/release/pulsar/helm-chart/ content

The chart references the files in https://downloads.apache.org/pulsar/helm-chart/ which are maintained
by SVN directory https://dist.apache.org/repos/dist/release/pulsar/helm-chart/.

If you remove releases from this directory, the URLs in index.yaml should be updated point to the 
https://archive.apache.org/dist/pulsar/helm-chart/ URL base instead of https://downloads.apache.org/pulsar/helm-chart/.
