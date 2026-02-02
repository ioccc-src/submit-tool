#!/usr/bin/env bash
#
# acct_status.sh - IOCCC submit server account status
#
# Given a file of addresses, one per line, apply a sed filter and
# write the result to stdout.
#
# Copyright (c) 2026 by Landon Curt Noll.  All Rights Reserved.
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
#
# Share and enjoy! :-)


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


# setup
#
export VERSION="2.0.0 2026-02-01"
NAME=$(basename "$0")
export NAME
export V_FLAG=0
#
export IOCCC_DIR="/var/ioccc"


# usage
#
export USAGE="usage: $0 [-h] [-v level] [-V] [ioccc_dir]

	-h		print help message and exit
	-v level	set verbosity level (def level: 0)
	-V		print version string and exit

	[ioccc_dir]	top level IOCCC submit server directory (def: $IOCCC_DIR)

Exit codes:
     0         all OK
     1	       readable ioccc_dir directory not found, cannot cd to ioccc_dir
     2         -h and help string printed or -V and version string printed
     3         command line error
     4	       missing critical sub-directories of ioccc_dir
     5	       missing critical files in sub-directories
     6	       httpd not enabled and/or active
 >= 10         internal error

$NAME version: $VERSION"


# parse command line
#
while getopts :hv:V: flag; do
  case "$flag" in
    h) echo "$USAGE" 1>&2
	exit 2
	;;
    v) V_FLAG="$OPTARG"
	;;
    V) echo "$VERSION"
	exit 2
	;;
    \?) echo "$0: ERROR: invalid option: -$OPTARG" 1>&2
	echo 1>&2
	echo "$USAGE" 1>&2
	exit 3
	;;
    :) echo "$0: ERROR: option -$OPTARG requires an argument" 1>&2
	echo 1>&2
	echo "$USAGE" 1>&2
	exit 3
	;;
    *) echo "$0: ERROR: unexpected value from getopts: $flag" 1>&2
	echo 1>&2
	echo "$USAGE" 1>&2
	exit 3
	;;
  esac
done
#
# remove the options
#
shift $(( OPTIND - 1 ));
#
if [[ $V_FLAG -ge 5 ]]; then
    echo "$0: debug[5]: file argument count: $#" 1>&2
fi
case "$#" in
0) ;;
1) IOCCC_DIR="$1"
   ;;
*) echo "$0: ERROR: expected 0 or 1 args, found: $#" 1>&2
   exit 3
   ;;
esac


# IOCCC_DIR must be a readable directory
#
if [[ ! -e $IOCCC_DIR ]]; then
    echo "$0: ERROR: ioccc_dir directory does not exist: $IOCCC_DIR" 1>&2
    exit 1
fi
if [[ ! -d $IOCCC_DIR ]]; then
    echo "$0: ERROR: ioccc_dir is not a directory: $IOCCC_DIR" 1>&2
    exit 1
fi
if [[ ! -r $IOCCC_DIR ]]; then
    echo "$0: ERROR: ioccc_dir is not a readable directory: $IOCCC_DIR" 1>&2
    exit 1
fi


# print running info if verbose
#
# If -v 3 or higher, print exported variables in order that they were exported.
#
if [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: LANG=$LANG" 1>&2
    echo "$0: debug[3]: LC_CTYPE=$LC_CTYPE" 1>&2
    echo "$0: debug[3]: LC_NUMERIC=$LC_NUMERIC" 1>&2
    echo "$0: debug[3]: LC_TIME=$LC_TIME" 1>&2
    echo "$0: debug[3]: LC_COLLATE=$LC_COLLATE" 1>&2
    echo "$0: debug[3]: LC_MONETARY=$LC_MONETARY" 1>&2
    echo "$0: debug[3]: LC_MESSAGES=$LC_MESSAGES" 1>&2
    echo "$0: debug[3]: LC_PAPER=$LC_PAPER" 1>&2
    echo "$0: debug[3]: LC_NAME=$LC_NAME" 1>&2
    echo "$0: debug[3]: LC_ADDRESS=$LC_ADDRESS" 1>&2
    echo "$0: debug[3]: LC_TELEPHONE=$LC_TELEPHONE" 1>&2
    echo "$0: debug[3]: LC_MEASUREMENT=$LC_MEASUREMENT" 1>&2
    echo "$0: debug[3]: LC_IDENTIFICATION=$LC_IDENTIFICATION" 1>&2
    echo "$0: debug[3]: LC_ALL=$LC_ALL" 1>&2
    echo "$0: debug[3]: VERSION=$VERSION" 1>&2
    echo "$0: debug[3]: NAME=$NAME" 1>&2
    echo "$0: debug[3]: V_FLAG=$V_FLAG" 1>&2
    echo "$0: debug[3]: IOCCC_DIR=$IOCCC_DIR" 1>&2
fi


# cd to IOCCC_DIR
#
export CD_FAILED=""
cd "$IOCCC_DIR" || CD_FAILED="true"
if [[ -n $CD_FAILED ]]; then
    echo "$0: ERROR: cd $IOCCC_DIR failed" 1>&2
    exit 1
fi


# verify critical readable sub-directories
#
for subdir in static templates; do

    # subdir must be a readable sub-directory
    #
    if [[ ! -e $subdir ]]; then
	echo "$0: ERROR: directory does not exist: $IOCCC_DIR/$subdir" 1>&2
	exit 4
    fi
    if [[ ! -d $subdir ]]; then
	echo "$0: ERROR: not a directory: $IOCCC_DIR/$subdir" 1>&2
	exit 4
    fi
    if [[ ! -r $subdir ]]; then
	echo "$0: ERROR: not readable sub-directory: $IOCCC_DIR/$subdir" 1>&2
	exit 4
    fi
done


# verify critical writable sub-directories
#
for subdir in etc staged tmp unexpected users wsgi; do

    # subdir must be a writable sub-directory
    #
    if [[ ! -e $subdir ]]; then
	echo "$0: ERROR: sub-directory does not exist: $IOCCC_DIR/$subdir" 1>&2
	exit 4
    fi
    if [[ ! -d $subdir ]]; then
	echo "$0: ERROR: not a sub-directory: $IOCCC_DIR/$subdir" 1>&2
	exit 4
    fi
    if [[ ! -w $subdir ]]; then
	echo "$0: ERROR: not writable sub-directory: $IOCCC_DIR/$subdir" 1>&2
	exit 4
    fi
done


# verify critical non-empty writable files under etc
#
export subdir="$IOCCC_DIR/etc"
for file in iocccpasswd.json save.iocccpasswd.json state.json; do

    # file must be a non-empty writable file under subdir
    #
    if [[ ! -e $subdir/$file ]]; then
	echo "$0: ERROR: file does not exist: $subdir/$file" 1>&2
	exit 5
    fi
    if [[ ! -f $subdir/$file ]]; then
	echo "$0: ERROR: not a file: $subdir/$file" 1>&2
	exit 5
    fi
    if [[ ! -w $subdir/$file ]]; then
	echo "$0: ERROR: not a writable file: $subdir/$file" 1>&2
	exit 5
    fi
    if [[ ! -s $subdir/$file ]]; then
	echo "$0: ERROR: not a non-empty writable file: $subdir/$file" 1>&2
	exit 5
    fi
done


# verify critical non-empty readable files under etc
#
export subdir="$IOCCC_DIR/etc"
for file in mail.head mail.tail pw.words requirements.txt; do

    # file must be a non-empty writable file under subdir
    #
    export subdir="$IOCCC_DIR/etc"
    if [[ ! -e $subdir ]]; then
	echo "$0: ERROR: file does not exist: $subdir/$file" 1>&2
	exit 5
    fi
    if [[ ! -f $subdir/$file ]]; then
	echo "$0: ERROR: not a file: $subdir/$file" 1>&2
	exit 5
    fi
    if [[ ! -r $subdir/$file ]]; then
	echo "$0: ERROR: not a readable file: $subdir/$file" 1>&2
	exit 5
    fi
    if [[ ! -s $subdir/$file ]]; then
	echo "$0: ERROR: not a non-empty readable file: $subdir/$file" 1>&2
	exit 5
    fi
done


# verify critical readable files under etc
#
export subdir="$IOCCC_DIR/etc"
for file in iocccpasswd.lock state.lock; do

    # file must be a readable file under subdir
    #
    export subdir="$IOCCC_DIR/etc"
    if [[ ! -e $subdir/$file ]]; then
	echo "$0: ERROR: file does not exist: $subdir/$file" 1>&2
	exit 5
    fi
    if [[ ! -f $subdir/$file ]]; then
	echo "$0: ERROR: not a file: $subdir/$file" 1>&2
	exit 5
    fi
    if [[ ! -r $subdir/$file ]]; then
	echo "$0: ERROR: not a readable file: $subdir/$file" 1>&2
	exit 5
    fi
done


# verify critical non-empty readable files under templates
#
export subdir="$IOCCC_DIR/templates"
for file in login.html not-open.html passwd.html submit.html; do

    # file must be a non-empty readable file under subdir
    #
    if [[ ! -e $subdir/$file ]]; then
	echo "$0: ERROR: file does not exist: $subdir/$file" 1>&2
	exit 5
    fi
    if [[ ! -f $subdir/$file ]]; then
	echo "$0: ERROR: not a file: $subdir/$file" 1>&2
	exit 5
    fi
    if [[ ! -r $subdir/$file ]]; then
	echo "$0: ERROR: not a readable file: $subdir/$file" 1>&2
	exit 5
    fi
    if [[ ! -s $subdir/$file ]]; then
	echo "$0: ERROR: not a non-empty readable file: $subdir/$file" 1>&2
	exit 5
    fi
done


# verify critical non-empty executable files under wsgi
#
export subdir="$IOCCC_DIR/wsgi"
# So far e have only one file under wsgi
#
# SC2043 (warning): This loop will only ever run once. Bad quoting or missing glob/expansion?
# https://www.shellcheck.net/wiki/SC2043
# shellcheck disable=SC2043
for file in ioccc.wsgi; do

    # file must be a non-empty executable file under subdir
    #
    if [[ ! -e $subdir/$file ]]; then
	echo "$0: ERROR: file does not exist: $subdir/$file" 1>&2
	exit 5
    fi
    if [[ ! -f $subdir/$file ]]; then
	echo "$0: ERROR: not a file: $subdir/$file" 1>&2
	exit 5
    fi
    if [[ ! -x $subdir/$file ]]; then
	echo "$0: ERROR: not a executable file: $subdir/$file" 1>&2
	exit 5
    fi
    if [[ ! -s $subdir/$file ]]; then
	echo "$0: ERROR: not a non-empty executable file: $subdir/$file" 1>&2
	exit 5
    fi
done
echo
echo "OK: $IOCCC_DIR"
echo


# show recent changes to IOCCCPASSWD_JSON
#
export IOCCCPASSWD_JSON="$IOCCC_DIR/etc/iocccpasswd.json"
cat "$IOCCCPASSWD_JSON" > "$IOCCC_DIR/tmp/i"
if ! cmp -s "$IOCCC_DIR/tmp/j" "$IOCCC_DIR/tmp/i"; then
    echo "Recent changes to $IOCCCPASSWD_JSON"
    echo
    diff --color -u "$IOCCC_DIR/tmp/j" "$IOCCC_DIR/tmp/i"
    echo
    echo "To acknowledge, run:"
    echo
    echo "cp -v -f -p tmp/i tmp/j ; cat tmp/j > etc/save.iocccpasswd.json ; diff -u etc/save.iocccpasswd.json etc/iocccpasswd.json"
    echo
fi


# report pw_change_by not yet completed
#
if grep -q '"pw_change_by".*"' "$IOCCCPASSWD_JSON"; then
    echo "pw_change_by not yet completed - see /home/ioccc/submit-tool/bin/expired_user.py"
    echo
    grep --color '"pw_change_by".*"' "$IOCCCPASSWD_JSON"
    echo
else
    echo "All accounts have changed their passwords"
    echo
fi


# count accounts
#
echo -n 'pw changed: ' ; grep -F pw_change_by "$IOCCCPASSWD_JSON" | grep -c -F null,
echo -n 'pw NOT-changed: ' ; grep -F pw_change_by "$IOCCCPASSWD_JSON" | grep -c -F -v null,
echo


# check on web service
#
if ! systemctl -q is-enabled httpd; then
    echo "$0: ERROR: httpd is not enabled" 1>&2
    exit 6
fi
if ! systemctl -q is-active httpd; then
    echo "$0: ERROR: httpd is not active" 1>&2
    exit 6
fi
echo "web service: enabled active"
echo


# All Done!!! All Done!!! -- Jessica Noll, Age 2
#
exit 0
