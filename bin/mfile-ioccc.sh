#!/usr/bin/env bash
#
# mfile-ioccc.sh - mail IOCCC registration list to user who-ioccc
#
# Copyright (c) 2024,2026 by Landon Curt Noll.  All Rights Reserved.
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
# chongo (Landon Curt Noll) /\oo/\
#
# http://www.isthe.com/chongo/index.html
# https://github.com/lcn2
#
# Share and enjoy!  :-)


# setup
#
export VERSION="1.1 2026-01-11"
NAME=$(basename "$0")
export NAME
#
export V_FLAG=0
#
export NOOP=
export DO_NOT_PROCESS=
#
S_NAIL_TOOL=$(type -P s-nail)
if [[ -z $S_NAIL_TOOL ]]; then
    S_NAIL_TOOL="s-nail"
fi
export EMAIL_FILE="/home/chongo/email"
export SEND_TO_USER="who-ioccc"


# usage
#
export USAGE="usage: $0 [-h] [-v level] [-V] [-n] [-N] [-s tool] [-S addr] [file]

    -h          print help message and exit
    -v level    set verbosity level (def level: $V_FLAG)
    -V          print version string and exit

    -n          go thru the actions, but do not update any files (def: do the action)
    -N          do not process anything, just parse arguments (def: process something)

    -s tool	path to s-nail tool (def: $S_NAIL_TOOL)
    -S addr	send to user addr (def: $SEND_TO_USER)

    [file]	file to send via email (def: use $EMAIL_FILE)

Exit codes:
     0         all OK
     1	       s-nail command failed
     2         -h and help string printed or -V and version string printed
     3         command line error
     5	       some internal tool is not found or not an executable file
 >= 10         internal error

$NAME version: $VERSION"


# parse command line
#
while getopts :hv:VnNs:S: flag; do
  case "$flag" in
    h) echo "$USAGE"
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
    s) S_NAIL_TOOL="$OPTARG"
        ;;
    S) SEND_TO_USER="$OPTARG"
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
if [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: debug level: $V_FLAG" 1>&2
fi
#
# remove the options
#
shift $(( OPTIND - 1 ));
#
# parse args
#
case "$#" in
0) ;;
1) EMAIL_FILE="$1" ;;
*) echo "$0: ERROR: expected 0 or 1 args, found: $#" 1>&2
   echo "$USAGE" 1>&2
   exit 3 ;;
esac


# verify that the s_nail tool is executable
#
if [[ ! -e $S_NAIL_TOOL ]]; then
    echo  "$0: ERROR: s_nail does not exist: $S_NAIL_TOOL" 1>&2
    exit 5
fi
if [[ ! -f $S_NAIL_TOOL ]]; then
    echo  "$0: ERROR: s_nail is not a regular file: $S_NAIL_TOOL" 1>&2
    exit 5
fi
if [[ ! -x $S_NAIL_TOOL ]]; then
    echo  "$0: ERROR: s_nail is not an executable file: $S_NAIL_TOOL" 1>&2
    exit 5
fi


# print running info if verbose
#
# If -v 3 or higher, print exported variables in order that they were exported.
#
if [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: VERSION=$VERSION" 1>&2
    echo "$0: debug[3]: NAME=$NAME" 1>&2
    echo "$0: debug[3]: V_FLAG=$V_FLAG" 1>&2
    echo "$0: debug[3]: NOOP=$NOOP" 1>&2
    echo "$0: debug[3]: DO_NOT_PROCESS=$DO_NOT_PROCESS" 1>&2
    echo "$0: debug[3]: S_NAIL_TOOL=$S_NAIL_TOOL" 1>&2
    echo "$0: debug[3]: EMAIL_FILE=$EMAIL_FILE" 1>&2
    echo "$0: debug[3]: SEND_TO_USER=$SEND_TO_USER" 1>&2
fi


# verify that the email file exists as a non-empty readable file
#
if [[ ! -e $EMAIL_FILE ]]; then
    echo "$0: ERROR: email file dpes not exist: $EMAIL_FILE" 1>&2
    exit 1
fi
if [[ ! -f $EMAIL_FILE ]]; then
    echo "$0: ERROR: email not a file: $EMAIL_FILE" 1>&2
    exit 1
fi
if [[ ! -r $EMAIL_FILE ]]; then
    echo "$0: ERROR: email not a readable file: $EMAIL_FILE" 1>&2
    exit 1
fi
if [[ ! -s $EMAIL_FILE ]]; then
    echo "$0: ERROR: email not a non-empty readable file: $EMAIL_FILE" 1>&2
    exit 1
fi


# -N stops early before any processing is performed
#
if [[ -n $DO_NOT_PROCESS ]]; then
    if [[ $V_FLAG -ge 3 ]]; then
	echo "$0: debug[3]: arguments parsed, -N given, exiting 0" 1>&2
    fi
    exit 0
fi


# email the file to the user
#
if [[ -z $NOOP ]]; then

    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to execute:" \
		    "LC_ALL=C $S_NAIL_TOOL -:/ -Sv15-compat -Sttycharset=utf-8 -Sfullnames --discard-empty-messages" \
		    "--subject='Request results: who' $SEND_TO_USER < $EMAIL_FILE" 2>&1
    fi
    LC_ALL=C "$S_NAIL_TOOL" -:/ -Sv15-compat -Sttycharset=utf-8 -Sfullnames --discard-empty-messages \
			    --subject='Request results: who' "$SEND_TO_USER" < "$EMAIL_FILE"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: s-nail failed, error code: $status" 1>&2
	exit 1
    fi

# case: -n
#
elif [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: because of -n, did not execute:" \
                "LC_ALL=C $S_NAIL_TOOL -:/ -Sv15-compat -Sttycharset=utf-8 -Sfullnames --discard-empty-messages" \
		"--subject='Request results: who' $SEND_TO_USER < $EMAIL_FILE" 2>&1
fi


# All Done!!! -- Jessica Noll, Age 2
#
exit 0
