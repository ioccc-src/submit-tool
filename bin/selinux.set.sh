#!/usr/bin/env bash
#
# selinux.set.sh - set SELinux got submit tool wsgi under Apache
#
# usage:
#
#   sudo selinux.set.sh
#
# Copyright (c) 2024 by Landon Curt Noll.  All Rights Reserved.
#
# Permission to use, copy, modify, and distribute this software and
# its documentation for any purpose and without fee is hereby granted,
# provided that the above copyright, this permission notice and text
# this comment, and the disclaimer below appear in all of the following:
#
#       supporting documentation
#       source copies
#       source works derived from this source
#       binaries derived from this source or from derived source
#
# LANDON CURT NOLL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
# INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO
# EVENT SHALL LANDON CURT NOLL BE LIABLE FOR ANY SPECIAL, INDIRECT OR
# CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF
# USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
# OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.
#
# chongo (Landon Curt Noll, http://www.isthe.com/chongo/index.html) /\oo/\


# firewall - run only with a bash that is version 5.1.8 or later
#
# The "/usr/bin/env bash" command must result in using a bash that
# is version 5.1.8 or later.
#
# We could relax this version and insist on version 4.2 or later.  Versions
# of bash between 4.2 and 5.1.7 might work.  However, to be safe, we will require
# bash version 5.1.8 or later.
#
# WHY 5.1.8 and not 4.2?  This safely is done because macOS Homebrew bash we
# often use is "version 5.2.26(1)-release" or later, and the RHEL Linux bash we
# use often use is "version 5.1.8(1)-release" or later.  These versions are what
# we initially tested.  We recommend you either upgrade bash or install a newer
# version of bash and adjust your $PATH so that "/usr/bin/env bash" finds a bash
# that is version 5.1.8 or later.
#
# NOTE: The macOS shipped, as of 2024 March 15, a version of bash is something like
#       bash "version 3.2.57(1)-release".  That macOS shipped version of bash
#       will NOT work.  For users of macOS we recommend you install Homebrew,
#       (see https://brew.sh), and then run "brew install bash" which will
#       typically install it into /opt/homebrew/bin/bash, and then arrange your $PATH
#       so that "/usr/bin/env bash" finds "/opt/homebrew/bin" (or whatever the
#       Homebrew bash is).
#
# NOTE: And while MacPorts might work, we noticed a number of subtle differences
#       with some of their ported tools to suggest you might be better off
#       with installing Homebrew (see https://brew.sh).  No disrespect is intended
#       to the MacPorts team as they do a commendable job.  Nevertheless we ran
#       into enough differences with MacPorts environments to suggest you
#       might find a better experience with this tool under Homebrew instead.
#
if [[ -z ${BASH_VERSINFO[0]} ||
         ${BASH_VERSINFO[0]} -lt 5 ||
         ${BASH_VERSINFO[0]} -eq 5 && ${BASH_VERSINFO[1]} -lt 1 ||
         ${BASH_VERSINFO[0]} -eq 5 && ${BASH_VERSINFO[1]} -eq 1 && ${BASH_VERSINFO[2]} -lt 8 ]]; then
    echo "$0: ERROR: bash version needs to be >= 5.1.8: $BASH_VERSION" 1>&2
    echo "$0: Warning: bash version >= 4.2 might work but 5.1.8 was the minimum we tested" 1>&2
    echo "$0: Notice: For macOS users: install Homebrew (see https://brew.sh), then run" \
         ""brew install bash" and then modify your \$PATH so that \"#!/usr/bin/env bash\"" \
         "finds the Homebrew installed (usually /opt/homebrew/bin/bash) version of bash" 1>&2
    exit 4
fi

# setup bash file matching
#
# We must declare arrays with -ag or -Ag, and we need loops to "export" modified variables.
# This requires a bash with a version 4.2 or later.  See the larger comment above about bash versions.
#
shopt -s nullglob       # enable expanded to nothing rather than remaining unexpanded
shopt -u failglob       # disable error message if no matches are found
shopt -u dotglob        # disable matching files starting with .
shopt -u nocaseglob     # disable strict case matching
shopt -u extglob        # enable extended globbing patterns
shopt -s globstar       # enable ** to match all files and zero or more directories and subdirectories


# IOCCC requires use of C locale
#
export LANG="C"
export LC_CTYPE="C"
export LC_NUMERIC="C"
export LC_TIME="C"
export LC_COLLATE="C"
export LC_MONETARY="C"
export LC_MESSAGES="C"
export LC_PAPER="C"
export LC_NAME="C"
export LC_ADDRESS="C"
export LC_TELEPHONE="C"
export LC_MEASUREMENT="C"
export LC_IDENTIFICATION="C"
export LC_ALL="C"


# setup variables
#
export VERSION="2.3.2 2026-08-25"
NAME=$(basename "$0")
export NAME


# must be root
#
MY_UID=$(id -u)
export MY_UID
if [[ $MY_UID -ne 0 ]]; then
    echo "$0: ERROR: must be root to run this code" 1>&2
    exit 1
fi


# setup /var/ioccc, /var/log/ioccc, /etc/httpd/conf, /var/log/trap-httpd, /var/log/httpd for SELinux
#
set -x
set -e

echo "=== Updating SELinux Contexts for IOCCC Submit Server ==="

# 1. Clear existing local context definitions for IOCCC paths to avoid collisions
semanage fcontext -d '/var/ioccc(/.*)?' 2>/dev/null || true
semanage fcontext -d '/var/ioccc/etc(/.*)?' 2>/dev/null || true
semanage fcontext -d '/var/ioccc/static(/.*)?' 2>/dev/null || true
semanage fcontext -d '/var/ioccc/templates(/.*)?' 2>/dev/null || true
semanage fcontext -d '/var/ioccc/users(/.*)?' 2>/dev/null || true
semanage fcontext -d '/var/ioccc/save.users(/.*)?' 2>/dev/null || true
semanage fcontext -d '/var/ioccc/staged(/.*)?' 2>/dev/null || true
semanage fcontext -d '/var/ioccc/tmp(/.*)?' 2>/dev/null || true
semanage fcontext -d '/var/ioccc/unexpected(/.*)?' 2>/dev/null || true
semanage fcontext -d '/var/ioccc/wsgi(/.*)?' 2>/dev/null || true
semanage fcontext -d -f f '/var/log/ioccc' 2>/dev/null || true
semanage fcontext -d '/var/log/ioccc' 2>/dev/null || true
semanage fcontext -d '/var/log/ioccc.*' 2>/dev/null || true

# 2. Add base context rule
semanage fcontext -a -t httpd_sys_content_t '/var/ioccc(/.*)?'

# 3. Add specific read-write context rules
semanage fcontext -a -t httpd_sys_rw_content_t '/var/ioccc/etc(/.*)?'
semanage fcontext -a -t httpd_sys_rw_content_t '/var/ioccc/users(/.*)?'
semanage fcontext -a -t httpd_sys_rw_content_t '/var/ioccc/save.users(/.*)?'
semanage fcontext -a -t httpd_sys_rw_content_t '/var/ioccc/staged(/.*)?'
semanage fcontext -a -t httpd_sys_rw_content_t '/var/ioccc/tmp(/.*)?'
semanage fcontext -a -t httpd_sys_rw_content_t '/var/ioccc/unexpected(/.*)?'

# 4. Add execution and static rules
semanage fcontext -a -t httpd_sys_content_t '/var/ioccc/static(/.*)?'
semanage fcontext -a -t httpd_sys_content_t '/var/ioccc/templates(/.*)?'
semanage fcontext -a -t httpd_sys_script_exec_t '/var/ioccc/wsgi(/.*)?'

# 5. Log context rules (covers /var/log/ioccc and any rotated variants)
semanage fcontext -a -t httpd_log_t '/var/log/ioccc.*'

# 6. Apply permissions and contexts
chown -Rv apache:apache /var/ioccc 2>/dev/null || true
chown -v root:adm /var/log/ioccc 2>/dev/null || true

restorecon -vFR /var/ioccc 2>/dev/null || true
restorecon -vF /var/log/ioccc* 2>/dev/null || true
restorecon -vF /etc/httpd/conf 2>/dev/null || true
restorecon -vFR /var/log/trap-httpd 2>/dev/null || true
restorecon -vFR /var/log/httpd 2>/dev/null || true

echo "=== Current Local SELinux Contexts ==="
semanage fcontext -l -C

set +e
set +x


# All Done!!! All Done!!! -- Jessica Noll, Age 2
#
exit 0
