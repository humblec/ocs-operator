#!/bin/bash
# https://github.com/red-hat-storage/ocs-ci/blob/master/docs/getting_started.md
set -e

source hack/common.sh 

mkdir -p $OUTDIR_OCS_CI
cd $OUTDIR_OCS_CI

DOWNLOAD_SRC=""
if ! [ -d "ocs-ci" ]; then
	DOWNLOAD_SRC="true"
elif ! [ "$(cat ocs-ci/git-hash)" = "$REDHAT_OCS_CI_HASH" ]; then
	rm -rf ocs-ci
	DOWNLOAD_SRC="true"
fi

if [ -n ${DOWNLOAD_SRC} ]; then
	echo "Cloning code from $REDHAT_OCS_CI_REPO using hash $REDHAT_OCS_CI_HASH"
	curl -L ${REDHAT_OCS_CI_REPO}/archive/${REDHAT_OCS_CI_HASH}/ocs-ci.tar.gz | tar xz ocs-ci-${REDHAT_OCS_CI_HASH}
	mv ocs-ci-${REDHAT_OCS_CI_HASH} ocs-ci
else
	echo "Using cached ocs-ci src"
fi

cd ocs-ci

# record the hash in a file so we don't redownload the source if nothing changed.
echo "$REDHAT_OCS_CI_HASH" > git-hash

# we are faking an openshift-install cluster directory here
# for the ocs-ci test suite. All we need is to provide
# the auth credentials in the predictable directory structure
mkdir -p fakecluster/auth
cp $KUBECONFIG fakecluster/auth/kubeconfig

# Create a Python virtual environment for the tests to execute with.
echo "Using $REDHAT_OCS_CI_PYTHON_BINARY"
$REDHAT_OCS_CI_PYTHON_BINARY -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# This is the test config we pass into ocs-ci's run-ci tool
cat << EOF > my-config.yaml
---
RUN:
  log_dir: "/tmp"
  kubeconfig_location: 'auth/kubeconfig' # relative from cluster_dir
  bin_dir: './bin'

DEPLOYMENT:
  force_download_installer: False
  force_download_client: False

ENV_DATA:
  cluster_name: null
  storage_cluster_name: 'test-storagecluster'
  storage_device_sets_name: "example-deviceset"
  cluster_namespace: 'openshift-storage'
  skip_ocp_deployment: true
  skip_ocs_deployment: true
EOF

echo "Running ocs-ci testsuite using -k $REDHAT_OCS_CI_TEST_EXPRESSION"
run-ci -k "$REDHAT_OCS_CI_TEST_EXPRESSION" --cluster-path "$(pwd)/fakecluster/" --ocsci-conf my-config.yaml
