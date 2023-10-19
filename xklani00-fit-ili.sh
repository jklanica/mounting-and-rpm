#!/bin/bash

# ... - commands to be installed
function install_miss_req () {
    for package in "$@"; do
        if ! command -v "$package" &> /dev/null
        then
            echo ".. downloading $package"
            dnf install "$package" -y -q || return 1
        fi
    done
}

# $1 - size with units
# $2 - image name
function create_img () {
    dd if=/dev/zero of="$2" bs="$1" count=1 &>/dev/null
}

# $1 - image name
# returns loop name in $LOOP_NAME
function create_loop () {
    LOOP_NAME=$(losetup --find --show "$1")
}

# $1 - fs type
# $2 - loop name
function create_fs () {
    mkfs -t "$1" "$2" &> /dev/null
}

# $1 - loop name
# $2 - mount point
# $3 - fs type
function edit_fstab () {
    echo "$1" "$2" "$3" defaults 0 1 >> /etc/fstab || return 1
    systemctl daemon-reload
}

# $1 - loop name
# $2 - mount point
function mount_loop () {
    if [[ ! -d "$2" ]]; then
        mkdir -p "$2" || return 1
    fi
    mount "$1" "$2"
}

# $1 - output directory
# ... - packages to be installed
function download_packages () {
    for package in "${@:2}"; do
        echo ".. downloading $package"
        yum download "$package" -y -q --downloaddir="$1" || return 1
    done
}

# $1 - repo directory
function generate_repodata () {
    cd "$1" || return 1

    echo ".. generating"
    createrepo "$1" &>/dev/null || return 1

    echo ".. setting selinux context"
    restorecon -Rv "$1" &>/dev/null
}

# $1 - repo name (without whitespace)
# $2 - repo full name
# $3 - repo url
function configure_repo_url () {
    local FILE_PATH="/etc/yum.repos.d/$1.repo"
    if [[ ! -e "$FILE_PATH" ]]; then
        mkdir -p "$(dirname "$FILE_PATH")" || return 1
        touch "$FILE_PATH" || return 1
    fi
    printf '%s\n' \
        "[$1]"   \
        "name=$2"   \
        "baseurl=$3" \
        "gpgcheck=0" \
        "enabled=1" \
        > "$FILE_PATH"
}

function launch_webserver () {
    service httpd start &>/dev/null
}

# $1 - repo name
function verify_repo_availability () {
    yum repolist | grep "$1" &> /dev/null
}

# $1 - block device name
function unmount () {
    umount -l "$1"
}

# $1 - block device name
function remount () {
    echo ".. mounting all filesystems according to /etc/fstab"
    mount -a || return 1
    echo ".. verifying filesystem is mounted"
    mount | grep "$1" &>/dev/null
}

# $1 - repo name
function print_info () {
    yum info --showduplicates --available --repo="$1"
    return 0
}

# $1 - command with arguments
# $2 - start message
function execute () {
    if [ -n "$2" ]; then
        echo "$2"
    fi
    if ! $1; then
        echo "failed"
        kill -s USR1 $TOP_PID
    fi
}

trap "exit 1" USR1
export TOP_PID=$$

MISSING_REQUIREMENTS="httpd createrepo"
UKOL_IMG=/var/tmp/ukol.img
HTML_UKOL=/var/www/html/ukol
ETC_FSTAB=/etc/fstab
REPO_NAME=ukol
FS_TYPE=ext4

execute "install_miss_req $MISSING_REQUIREMENTS"                                "0) Downloading dependencies"
execute "create_img 200MB $UKOL_IMG"                                            "1) Creating 200 MB file $UKOL_IMG"
execute "create_loop $UKOL_IMG"                                                 "2) Creating loop device for $UKOL_IMG"
execute "create_fs $FS_TYPE $LOOP_NAME"                                         "3) Creating filesystem $FS_TYPE on the new loop device"
execute "edit_fstab $LOOP_NAME $HTML_UKOL $FS_TYPE"                             "4) Editing $ETC_FSTAB for automatic filesystem mounting"
execute "mount_loop $LOOP_NAME $HTML_UKOL"                                      "5) Mounting filesystem to $HTML_UKOL"
execute "download_packages $HTML_UKOL $*"                                       "6) Downloading packages"
execute "generate_repodata $HTML_UKOL"                                          "7) Generating repodata in $HTML_UKOL"
execute "configure_repo_url $REPO_NAME $REPO_NAME http://localhost/$REPO_NAME"  "8) Configuring /etc/yum.repos.d/$REPO_NAME.repo for localhost url"
execute "launch_webserver"                                                      "9) Launching webserver"
execute "verify_repo_availability $REPO_NAME"                                   "10) Verification of $REPO_NAME repository availability"
execute "unmount $LOOP_NAME"                                                    "11) Unmounting filesystem from $HTML_UKOL" 
execute "remount $LOOP_NAME"                                                    "12) Remounting filesystem through $ETC_FSTAB and verifying mount state" 
execute "print_info $REPO_NAME"                                                 "13) Printing info about all available packages in \"$REPO_NAME\" repository" 
