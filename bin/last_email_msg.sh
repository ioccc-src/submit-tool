#!/usr/bin/env bash
#
# last_email_msg.sh - print last email and then delete all email
#
# We print the last email message, if any are found, and then
# delete all email messages, if any exist.
#
# Copyright (c) 2025 by Landon Curt Noll.  All Rights Reserved.
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


# setup
#
export VERSION="2.2.0 2025-03-13"
NAME=$(basename "$0")
export NAME
export V_FLAG=0
#
export NOOP=
export DO_NOT_PROCESS=
#
export S_NAIL
if [[ -z $S_NAIL ]]; then
    S_NAIL=$(type -P s-nail)
    if [[ -z $S_NAIL ]]; then
	S_NAIL="/bin/s-nail"
    fi
fi

# build s-nail arguments
#
unset S_NAIL_OPTION
declare -ag S_NAIL_OPTION
S_NAIL_OPTION+=("-:/")
S_NAIL_OPTION+=("-Sv15-compat")
S_NAIL_OPTION+=("-Sumask=0")
S_NAIL_OPTION+=("-Sttycharset=utf-8")
export MAILBOX_USER=
S_NAIL_CMDS='p $ ; d * ; quit'


# usage
#
export USAGE="usage: $0 [-h] [-v level] [-V] [-n] [-N] [-m mailbox_user] [-S s-nail]

	-h		print help message and exit
	-v level	set verbosity level (def level: 0)
	-V		print version string and exit

	-n		go thru the actions, but do not update any files (def: do the action)
	-N		do not process anything, just parse arguments (def: process something)

	-m mailbox_user		read s-nail mailbox for user -u (def: read for current user)

	-S s-nail	Email sending tool path (def: $S_NAIL)

Exit codes:
     0         all OK
     1         s-nail tool failed exited non-zero
     2         -h and help string printed or -V and version string printed
     3         command line error
     5         s-nail tool not found
 >= 10         internal error

$NAME version: $VERSION"


# parse command line
#
while getopts :hv:VnNm:S: flag; do
  case "$flag" in
    h) echo "$USAGE" 1>&2
	exit 2
	;;
    v) V_FLAG="$OPTARG"
	;;
    V) echo "$VERSION"
	exit 2
	;;
    n) NOOP="-n"
	;;
    N) DO_NOT_PROCESS="-N"
	;;
    m) MAILBOX_USER="$OPTARG"
	;;
    S) S_NAIL="$OPTARG"
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
if [[ $# -ne 0 ]]; then
    echo "$0: ERROR: expected 0 args, found: $#" 1>&2
    exit 3
fi


# add -u MAILBOX_USER to smail command if -u was given
#
if [[ -n $MAILBOX_USER ]]; then
    S_NAIL_OPTION+=("-u$MAILBOX_USER")
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
    echo "$0: debug[3]: NOOP=$NOOP" 1>&2
    echo "$0: debug[3]: DO_NOT_PROCESS=$DO_NOT_PROCESS" 1>&2
    echo "$0: debug[3]: S_NAIL=$S_NAIL" 1>&2
    for index in "${!S_NAIL_OPTION[@]}"; do
        echo "$0: debug[3]: S_NAIL_OPTION[$index]=${S_NAIL_OPTION[$index]}" 1>&2
    done
    echo "$0: debug[3]: MAILBOX_USER=$MAILBOX_USER" 1>&2
    echo "$0: debug[3]: S_NAIL_CMDS=$S_NAIL_CMDS" 1>&2
fi


# verify we have s-nail
#
if [[ -z $S_NAIL || ! -x $S_NAIL ]]; then
    echo "$0: ERROR: s-nail executable not found: $S_NAIL" 1>&2
    exit 5
fi


# -N stops early before any processing is performed
#
if [[ -n $DO_NOT_PROCESS ]]; then
    if [[ $V_FLAG -ge 3 ]]; then
	echo "$0: debug[3]: arguments parsed, -N given, exiting 0" 1>&2
    fi
    exit 0
fi


# print last email and then delete all email
#
# We print the last email message, if any are found, and then
# delete all email messages, if any exist.
#
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to run: LC_ALL=C $S_NAIL ${S_NAIL_OPTION[*]} <<< $S_NAIL_CMDS 2>/dev/null" 1>&2
    fi
    LC_ALL=C "$S_NAIL" "${S_NAIL_OPTION[@]}" <<< "$S_NAIL_CMDS" 2>/dev/null
    status="$?"
    if [[ $status -ge 2 ]]; then
	echo "$0: ERROR: LC_ALL=C $S_NAIL ${S_NAIL_OPTION[*]} <<< $S_NAIL_CMDS 2>/dev/null failed, error: $status" 1>&2
	exit 1
    fi
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not run: LC_ALL=C $S_NAIL ${S_NAIL_OPTION[*]} <<< $S_NAIL_CMDS 2>/dev/null" 1>&2
fi


# All Done!!! All Done!!! -- Jessica Noll, Age 2
#
exit 0
