#!/bin/bash 
#
# Rewrite Scaleway initrd and kexec into Ubuntu kernel
#
# Author: stuffo (https://github.com/stuffo/)
# Location: https://github.com/stuffo/scaleway-ubuntukernel
#

# kernel modules to add to the Scaleway initrd to allow Ubuntu kernel to mount
# nbd devices. Path prefix is /lib/modules/<kernel version>
REQUIRED_MODULES="net/virtio_net block/virtio_blk block/nbd"

# current Scaleway IPXE boot script
SCW_IPXE_SCRIPT="http://169.254.42.42/ipxe"

# where to account current Ubuntu kernel version
UBUNTU_KERNEL_STAMP="/boot/.ubuntukernel-version"

# default value initialization
INITRD_KERNEL_VERSION="none"
UBUNTU_KERNEL_VERSION="wedontknowyet"

set -eu
set -o pipefail
shopt -s nullglob
shopt -s dotglob
umask 022

export LC_ALL=C
export LANG=C
unset LANGUAGE

log() {
    echo "$@" >&2
}

fatal() {
    log "$@"
    log "Exiting."
    exit 1
}

rebuild_initrd() {
    local workdir=$(mktemp -d)

    # get original initrd url from IPXE
    local orig_initrd=$(curl -s $SCW_IPXE_SCRIPT | grep ^initrd | grep -P -o 'http://\S+')
    log "Scaleway initrd: $orig_initrd"

    log "+ get scaleway initrd"
    curl -s -o $workdir/uInitrd.orig.gz $orig_initrd
    log "+ extract scaleway initrd"
    local initrd_dir=$(mktemp -d initrd.XXXXXX)
    ( cd $initrd_dir && gunzip < $workdir/uInitrd.orig.gz | cpio -i --quiet > /dev/null )
    rm -f $workdir/uInitrd.orig.gz

    # copy kernel modules
    local insmod_command=
    local modname mod
    local initrd_mod_dir="$initrd_dir/lib/modules/$UBUNTU_KERNEL_VERSION"
    mkdir -p $initrd_mod_dir
    for mod in $REQUIRED_MODULES ; do
        log "+ add module $mod to initrd"
        modname=$(basename $mod).ko
        cp /lib/modules/$UBUNTU_KERNEL_VERSION/kernel/drivers/$mod.ko $initrd_mod_dir/$modname
        insmod_command=$insmod_command"insmod /lib/modules/$UBUNTU_KERNEL_VERSION/$modname\n"
    done

    log "+ prepend loading modules before entering scaleway initrd"
    mv $initrd_dir/init $initrd_dir/init.scw
    cat > $initrd_dir/init <<-EOF 
#!/bin/sh 
# this was added by ubuntukernel-load.sh to load Ubuntu kernel modules
# before executing the Scaleway init script. Please do not remove.
/bin/busybox mkdir -p /bin /sbin /etc /proc /sys /newroot /usr/bin /usr/sbin
/bin/busybox --install -s
EOF
    echo -e $insmod_command >> $initrd_dir/init
    echo '. init.scw' >> $initrd_dir/init
    chmod 755 $initrd_dir/init

    log "+ rebuild initrd archive"
    ( cd $initrd_dir && find . -print0 | cpio --quiet --null -o --format=newc | gzip -9 > /boot/uInitrd-$UBUNTU_KERNEL_VERSION.gz )

    # record kernel version we just integrated into intird for later
    echo $UBUNTU_KERNEL_VERSION > $UBUNTU_KERNEL_STAMP

    rm -fr $initrd_dir $workdir
}

shutdown_initrd_kexec_check() {
    # compat for old initrds which don't know how to kexec
    if ! grep -q 'kexec -e' /run/initramfs/shutdown  ; then
        log "current initrd won't kexec automatically. patching it."
        fixup_shutdown_initrd
    fi
}

fixup_shutdown_initrd() {
    mv /run/initramfs/shutdown /tmp/oldshutdown
    {
        head -n -1 /tmp/oldshutdown
        echo "kexec -e" 
    } > /run/initramfs/shutdown && chmod 755 /run/initramfs/shutdown
    rm -f /tmp/oldshutdown
}

get_kernel_version() {
    # last linux-image-* package in the list is the current kernel
    UBUNTU_KERNEL_VERSION=$(dpkg -l "linux-image*"|grep ^ii| tail -1 |awk '{print $2}'|cut -f3- -d-)
    if [ -r $UBUNTU_KERNEL_STAMP ] ; then
        INITRD_KERNEL_VERSION=$(cat $UBUNTU_KERNEL_STAMP)
    fi
    log "Ubuntu kernel version: $UBUNTU_KERNEL_VERSION"
    log "Initrd kernel version: $INITRD_KERNEL_VERSION"
}

sanity_checks() {
    [ ${EUID} -eq 0 ] || fatal "Script must be run as root."
    [ ${UID} -eq 0 ] || fatal "Script must be run as root."
    if [ ! -r /proc/sys/kernel/kexec_load_disabled ]  ; then
        fatal "kernel has no kexec support. please change bootscript."
    fi

    if [ ! -x /run/initramfs/sbin/kexec ] ; then
        fatal "current initrd has no kexec binary. kexec will fail."
    fi
}

# 
# main
#
sanity_checks
shutdown_initrd_kexec_check

get_kernel_version
if [ "$UBUNTU_KERNEL_VERSION" != "$INITRD_KERNEL_VERSION" ] ; then
    rebuild_initrd
fi

# we disable some features of the Scaleway initrd as they are superfluous
# for a kexeced environment 
log "Kexec engaged. Make it So!"
kexec -l /boot/vmlinuz-$UBUNTU_KERNEL_VERSION \
    --initrd=/boot/uInitrd-$UBUNTU_KERNEL_VERSION.gz \
    --command-line="$(cat /proc/cmdline) is_in_kexec=yes NO_SIGNAL_STATE=1 DONT_FETCH_KERNEL_MODULES=1 NO_NTPDATE=1 ubuntukernel" && systemctl kexec
