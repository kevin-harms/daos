#!/bin/bash

set -ex -o pipefail

# shellcheck disable=SC1091
if [ -f .localenv ]; then
    # read (i.e. environment, etc.) overrides
    . .localenv
fi

TEST_TAG="${1:-quick}"

HOSTPREFIX=${HOSTPREFIX-${HOSTNAME%%.*}}
NFS_SERVER=${NFS_SERVER:-$HOSTPREFIX}

trap 'echo "encountered an unchecked return code, exiting with error"' ERR

# put yaml files back
restore_dist_files() {
    local dist_files="$*"

    for file in $dist_files; do
        if [ -f "$file".dist ]; then
            mv -f "$file".dist "$file"
        fi
    done

}

# shellcheck disable=SC1091
. .build_vars.sh

#yum install python2-avocado.noarch                               \
#            python2-avocado-plugins-output-html.noarch           \
#            python2-avocado-plugins-varianter-yaml-to-mux.noarch \
#            python2-aexpect.noarch

# set our machine names
#yaml_files=($(find . -name \*.yaml))
mapfile -t yaml_files < <(find src/tests/ftest -name \*.yaml)

trap 'set +e; restore_dist_files "${yaml_files[@]}"' EXIT

# shellcheck disable=SC2086
sed -i.dist -e "s/- boro-A/- ${HOSTPREFIX}vm2/g" \
            -e "s/- boro-B/- ${HOSTPREFIX}vm3/g" \
            -e "s/- boro-C/- ${HOSTPREFIX}vm4/g" \
            -e "s/- boro-D/- ${HOSTPREFIX}vm5/g" \
            -e "s/- boro-E/- ${HOSTPREFIX}vm6/g" \
            -e "s/- boro-F/- ${HOSTPREFIX}vm7/g" \
            -e "s/- boro-G/- ${HOSTPREFIX}vm8/g" \
            -e "s/- boro-H/- ${HOSTPREFIX}vm9/g" "${yaml_files[@]}"


# let's output to a dir in the tree
rm -rf src/tests/ftest/avocado ./*_results.xml
mkdir -p src/tests/ftest/avocado/job-results

# shellcheck disable=SC2154
trap 'set +e
restore_dist_files "${yaml_files[@]}"
i=5
# due to flakiness on wolf-53, try this several times
while [ $i -gt 0 ]; do
    pdsh -R ssh -S -w ${HOSTPREFIX}vm[1-9] "sudo umount /mnt/daos
    x=0
    while [ \$x -lt 30 ] &&
          grep $DAOS_BASE /proc/mounts &&
          ! sudo umount $DAOS_BASE; do
        sleep 1
        let x+=1
    done
    sudo sed -i -e \"/added by ftest.sh/d\" /etc/fstab
    sudo rmdir $DAOS_BASE" 2>&1 | dshbak -c
    if [ ${PIPESTATUS[0]} = 0 ]; then
        i=0
    fi
    let i-=1
done' EXIT

DAOS_BASE=${SL_PREFIX%/install}
if ! pdsh -R ssh -S -w "${HOSTPREFIX}"vm[1-9] "set -ex
ulimit -c unlimited
if [ \"\${HOSTNAME%%%%.*}\" != \"${HOSTPREFIX}\"vm1 ]; then
    if grep /mnt/daos\\  /proc/mounts; then
        sudo umount /mnt/daos
    else
        if [ ! -d /mnt/daos ]; then
            sudo mkdir -p /mnt/daos
        fi
    fi
    sudo ed <<EOF /etc/fstab
\\\$a
tmpfs /mnt/daos tmpfs rw,relatime,size=16777216k 0 0 # added by ftest.sh
.
wq
EOF
    sudo mount /mnt/daos
fi
sudo mkdir -p $DAOS_BASE
sudo ed <<EOF /etc/fstab
\\\$a
$NFS_SERVER:$PWD $DAOS_BASE nfs defaults 0 0 # added by ftest.sh
.
wq
EOF
sudo mount $DAOS_BASE
rm -rf /tmp/Functional_$TEST_TAG/
mkdir -p /tmp/Functional_$TEST_TAG/" 2>&1 | dshbak -c; then
    echo "Cluster setup (i.e. provisioning) failed"
    exit 1
fi

# shellcheck disable=SC2029
if ! ssh "${HOSTPREFIX}"vm1 "set -ex
ulimit -c unlimited
rm -rf $DAOS_BASE/install/tmp
mkdir -p $DAOS_BASE/install/tmp
cd $DAOS_BASE
export CRT_ATTACH_INFO_PATH=$DAOS_BASE/install/tmp
export DAOS_SINGLETON_CLI=1
export CRT_CTX_SHARE_ADDR=1
export CRT_PHY_ADDR_STR=ofi+sockets
export ABT_ENV_MAX_NUM_XSTREAMS=64
export ABT_MAX_NUM_XSTREAMS=64
export OFI_INTERFACE=eth0
export OFI_PORT=23350
# At Oct2018 Longmond F2F it was decided that per-server logs are preferred
# But now we need to collect them!
export DD_LOG=/tmp/Functional_$TEST_TAG/daos.log
export DD_SUBSYS=\"\"
export DD_MASK=all
export D_LOG_FILE=/tmp/Functional_$TEST_TAG/daos.log
export D_LOG_MASK=DEBUG,RPC=ERR,MEM=ERR

mkdir -p ~/.config/avocado/
cat <<EOF > ~/.config/avocado/avocado.conf
[datadir.paths]
logs_dir = $DAOS_BASE/src/tests/ftest/avocado/job-results
EOF

# apply fix for https://github.com/avocado-framework/avocado/issues/2908
sudo ed <<EOF /usr/lib/python2.7/site-packages/avocado/core/runner.py
/TIMEOUT_TEST_INTERRUPTED/s/[0-9]*$/60/
wq
EOF
# apply fix for https://github.com/avocado-framework/avocado/pull/2922
if grep \"testsuite.setAttribute('name', 'avocado')\" \
    /usr/lib/python2.7/site-packages/avocado/plugins/xunit.py; then
    sudo ed <<EOF /usr/lib/python2.7/site-packages/avocado/plugins/xunit.py
/testsuite.setAttribute('name', 'avocado')/s/'avocado'/os.path.basename(os.path.dirname(result.logfile))/
wq
EOF
fi

pushd src/tests/ftest

# make sure no lingering corefiles exist
rm -f core.*

# now run it!
if ! ./launch.py -s \"$TEST_TAG\"; then
    rc=\${PIPESTATUS[0]}
else
    rc=0
fi
ls -l

# get stacktraces for the core files
if ls core.*; then
    # this really should be a debuginfo-install command but our systems lag
    # current releases
    if ! rpm -q python-debuginfo-2.7.5-69.el7_5.x86_64; then
        sudo yum install http://debuginfo.centos.org/7/x86_64/python-debuginfo-2.7.5-69.el7_5.x86_64.rpm
    fi
    sudo yum -y install gdb
    for file in core.*; do
        gdb -ex \"set pagination off\"                 \
            -ex \"thread apply all bt full\"           \
            -ex \"detach\"                             \
            -ex \"quit\"                               \
            /usr/bin/python2 \$file > \$file.stacktrace
    done
fi

exit \$rc"; then
    rc=${PIPESTATUS[0]}
else
    rc=0
fi

# collect the logs
if ! rpdcp -R ssh -w "${HOSTPREFIX}"vm[1-9] \
    /tmp/Functional_"$TEST_TAG"/\*daos.log "$PWD"/; then
    echo "Copying daos.logs from remote nodes failed"
    # pass
fi
ls -l
exit "$rc"
