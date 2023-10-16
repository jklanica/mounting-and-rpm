#!/bin/bash

function install_miss_req () {
    return 0
}

function create_img () {
    return 0
}

function create_loop () {
    # $LOOP_NAME
    return 0
}

function create_fs () {
    return 0
}

function edit_fstab () {
    return 0
}

function mount () {
    return 0
}

function download_packages () {
    for package in "$@"; do
        echo ".. downloading $package"
    done
}

function generate_repodata () {
    echo ".. generating"
    echo ".. setting selinux context"
    return 0
}

function configure_repo_url () {
    echo ".. generating"
    echo ".. setting selinux context"
    return 0
}

function install_and_launch_webserver () {
    echo ".. installing"
    echo ".. launching"
    return 0
}

function verify_repo_availability () {
    return 0
}

function unmount () {
    return 0
}

function remount () {
    echo ".. mounting all filesystems according to /etc/fstab"
    echo ".. verifying filesystem is mounted"
    return 0
}

function print_info () {
    return 0
}

function execute () {
    if [ ! -z "$2" ]; then
        echo "$2"
    fi
    if ! $1; then
        echo "failed"
        kill -s USR1 $TOP_PID
    fi
}

trap "exit 1" USR1
export TOP_PID=$$

MISSING_REQUIREMENTS=""
UKOL_IMG=/var/tmp/ukol.img
HTML_UKOL=/var/www/html/ukol
ETC_FSTAB=/etc/fstab

execute "install_miss_req $MISSING_REQUIREMENTS"
execute "create_img 200MB $UKOL_IMG" "1) Creating 200 MB file $UKOL_IMG"
execute "create_loop $UKOL_IMG" "2) Creating loop device for $UKOL_IMG"
execute "create_fs $LOOP_NAME" "3) Creating filesystem ext4 on the new loop device"
execute "edit_fstab $LOOP_NAME" "4) Editing $ETC_FSTAB for automatic filesystem mounting"
execute "mount $LOOP_NAME $HTML_UKOL" "5) Mounting filesystem to $HTML_UKOL"
execute "download_packages $*" "6) Downloading packages"
execute "generate_repodata $HTML_UKOL" "7) Generating repodata in $HTML_UKOL"
execute "configure_repo_url ukol http://localhost/ukol" "8) Configuring /etc/yum.repos.d/ukol.repo for localhost url"
execute "install_and_launch_webserver" "9) Installing and launching webserver"
execute "verify_repo_availability" "10) Verification of ukol repository availability"
execute "unmount" "11) Unmounting filesystem from $HTML_UKOL" 
execute "remount" "12) Remounting filesystem through $ETC_FSTAB and verifying mount state" 
execute "print_info" "13) Printing info about all available packages in \"ukol\" repository" 
