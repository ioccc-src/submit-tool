#!/usr/bin/env bash
#
# ssh_email_pr.sh - run the email_pr.py command, via run.sh on a remote IOCCC submit server
#
# Using the via run.sh too on the remote IOCCC submit server, run email_pr.py
# to print the email addresses found in the IOCCC password file on the IOCCC submit server.
# If any email addresses found, then we will update the iocccpasswd.lst file.
#
# NOTE: For nearly environment variables initialized in the "setup" section,
#	those environment variables default any value found in the environment.
#	If no such environment variable exists, or it is empty, then
#	the variables initialized to a default value in the "setup" section.
#
# NOTE: Later, after command line processing, the "ioccc.rc" file is sourced
#	(usually "$HOME/.ioccc.rc" or as modified by "-i ioccc.rc") where any
#	environment variables will override any existing environment variables.
#	unless "-I" was which in which case the "ioccc.rc" file is ignored.
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
#	bash "version 3.2.57(1)-release".  That macOS shipped version of bash
#	will NOT work.  For users of macOS we recommend you install Homebrew,
#	(see https://brew.sh), and then run "brew install bash" which will
#	typically install it into /opt/homebrew/bin/bash, and then arrange your $PATH
#	so that "/usr/bin/env bash" finds "/opt/homebrew/bin" (or whatever the
#	Homebrew bash is).
#
# NOTE: And while MacPorts might work, we noticed a number of subtle differences
#	with some of their ported tools to suggest you might be better off
#	with installing Homebrew (see https://brew.sh).  No disrespect is intended
#	to the MacPorts team as they do a commendable job.  Nevertheless we ran
#	into enough differences with MacPorts environments to suggest you
#	might find a better experience with this tool under Homebrew instead.
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
shopt -s nullglob	# enable expanded to nothing rather than remaining unexpanded
shopt -u failglob	# disable error message if no matches are found
shopt -u dotglob	# disable matching files starting with .
shopt -u nocaseglob	# disable strict case matching
shopt -u extglob	# enable extended globbing patterns
shopt -s globstar	# enable ** to match all files and zero or more directories and subdirectories


# setup
#
export VERSION="2.1.0 2025-02-28"
NAME=$(basename "$0")
export NAME
export V_FLAG=0
#
export NOOP=
export DO_NOT_PROCESS=
#
export TMPDIR
if [[ -z $TMPDIR ]]; then
    TMPDIR="/tmp"
fi
#
export IOCCC_RC
if [[ -z $IOCCC_RC ]]; then
    IOCCC_RC="$HOME/.ioccc.rc"
fi
#
export RMT_PORT
if [[ -z $RMT_PORT ]]; then
    RMT_PORT=22
fi
#
export RMT_USER
if [[ -z $RMT_USER ]]; then
    export USER_NAME
    if [[ -z $USER_NAME ]]; then
	USER_NAME=$(id -u -n)
    fi
    if [[ -z $USER_NAME ]]; then
	RMT_USER="nobody"
    else
	RMT_USER="$USER_NAME"
    fi
fi
#
export SERVER
if [[ -z $SERVER ]]; then
    SERVER="unknown.example.org"
fi
#
export SSH_RUN_SH
if [[ -z $SSH_RUN_SH ]]; then
    SSH_RUN_SH="/usr/ioccc/sbin/ssh_run.sh"
fi
#
export RMT_EMAIL_PR_PY
if [[ -z $RMT_EMAIL_PR_PY ]]; then
    RMT_EMAIL_PR_PY="/usr/ioccc/bin/email_pr.py"
fi


# usage
#
export USAGE="usage: $0 [-h] [-v level] [-V] [-n] [-N] [-t appdir] [-T tmpdir] [-i ioccc.rc] [-I]
	[-p rmt_port] [-u rmt_user] [-H rmt_host] [-s ssh_run]
	[-c email_pr] iocccpasswd.lst

	-h		print help message and exit
	-v level	set verbosity level (def level: 0)
	-V		print version string and exit

	-n		go thru the actions, but do not update any files (def: do the action)
	-N		do not process anything, just parse arguments (def: process something)

	-T tmpdir	form temp files under tmpdir (def: $TMPDIR)

	-i ioccc.rc	Use ioccc.rc as the rc startup file (def: $IOCCC_RC)
	-I		Do not use any rc startup file (def: do)

	-p rmt_port	use ssh TCP port (def: $RMT_PORT)
	-u rmt_user	ssh into this user (def: $RMT_USER)
	-H rmt_host	ssh host to use (def: $SERVER)

	-s ssh_run	use local ssh_run to ssh (def: $SSH_RUN_SH)

	-c email_pr	remote email_pr.py tool on the remote server (def: $RMT_EMAIL_PR_PY)

	iocccpasswd.lst	replace iocccpasswd.lst if email addresses found in remote IOCCC password file

Exit codes:
     0        all OK
     2        -h and help string printed or -V and version string printed
     3        command line error
     4        source of ioccc.rc file failed
     5        some critical local executable tool not found
     6        remote execution of a tool failed, returned an exit code, or returned a malformed response
     7        topdir is not a directory, or cannot cd to topdir

 >= 10        internal error

$NAME version: $VERSION"


# parse command line
#
while getopts :hv:VnNT:i:Ip:u:H:s:r:c: flag; do
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
    T) TMPDIR="$OPTARG"
	;;
    i) IOCCC_RC="$OPTARG"
	;;
    I) CAP_I_FLAG="true"
	;;
    p) RMT_PORT="$OPTARG"
	;;
    u) RMT_USER="$OPTARG"
	;;
    H) SERVER="$OPTARG"
	;;
    s) SSH_RUN_SH="$OPTARG"
	;;
    c) RMT_EMAIL_PR_PY="$OPTARG"
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
if [[ $# -ne 1 ]]; then
    echo "$0: ERROR: expected 1 arg, found: $#" 1>&2
    exit 3
fi
export IOCCCPASSWD_LST="$1"


# unless -I, verify the ioccc.rc file, if it exists
#
if [[ -z $CAP_I_FLAG ]]; then
    # if we do not have a readable ioccc.rc file, remove the IOCCC_RC value
    if [[ ! -r $IOCCC_RC ]]; then
	IOCCC_RC=""
    fi
else
    # -I used, remove the IOCCC_RC value
    IOCCC_RC=""
fi


# If we still have an IOCCC_RC value, source it
#
if [[ -n $IOCCC_RC ]]; then
    export status=0
    if [[ $V_FLAG -ge 3 ]]; then
	echo "$0: debug[3]: about to source $IOCCC_RC" 1>&2
    fi
    # SC1090 (warning): ShellCheck can't follow non-constant source. Use a directive to specify location.
    # https://www.shellcheck.net/wiki/SC1090
    # shellcheck disable=SC1090
    source "$IOCCC_RC"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: source $IOCCC_RC failed, error: $status" 1>&2
	exit 4
    fi
fi


# firewall - SSH_RUN_SH must be executable
#
if [[ ! -x $SSH_RUN_SH ]]; then
    echo "$0: ERROR: ssh tool not executable: $SSH_RUN_SH" 1>&2
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
    echo "$0: debug[3]: IOCCC_RC=$IOCCC_RC" 1>&2
    echo "$0: debug[3]: CAP_I_FLAG=$CAP_I_FLAG" 1>&2
    echo "$0: debug[3]: RMT_PORT=$RMT_PORT" 1>&2
    echo "$0: debug[3]: RMT_USER=$RMT_USER" 1>&2
    echo "$0: debug[3]: SERVER=$SERVER" 1>&2
    echo "$0: debug[3]: SSH_RUN_SH=$SSH_RUN_SH" 1>&2
    echo "$0: debug[3]: RMT_EMAIL_PR_PY=$RMT_EMAIL_PR_PY" 1>&2
    echo "$0: debug[3]: IOCCCPASSWD_LST=$IOCCCPASSWD_LST" 1>&2
fi


# tmpdir must be a writable directory
#
if [[ ! -d $TMPDIR ]]; then
    mkdir -p "$TMPDIR"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: mkdir -p $TMPDIR failed, error: $status" 1>&2
	exit 10
    fi
fi
if [[ ! -d $TMPDIR ]]; then
    echo "$0: ERROR: cannot create TMPDIR directory: $TMPDIR" 1>&2
    exit 11
fi
if [[ ! -w $TMPDIR ]]; then
    chmod 2770 "$TMPDIR"
    status="$?"
    if [[ $status -ne 0 ]]; then
        echo "$0: ERROR: chmod 2770 $TMPDIR ailed, error: $status" 1>&2
	exit 12
    fi
fi
if [[ ! -w $TMPDIR ]]; then
    echo "$0: ERROR: cannot make TMPDIR directory writable: $TMPDIR" 1>&2
    exit 13
fi


# form temporary output file
#
export TMP_OUTPUT="$TMPDIR/.tmp.$NAME.OUTPUT.$$.tmp"
if [[ $V_FLAG -ge 3 ]]; then
    echo  "$0: debug[3]: temporary output file: $TMP_OUTPUT" 1>&2
fi
trap 'rm -f $TMP_OUTPUT; exit' 0 1 2 3 15
rm -f "$TMP_OUTPUT"
if [[ -e $TMP_OUTPUT ]]; then
    echo "$0: ERROR: cannot remove output file: $TMP_OUTPUT" 1>&2
    exit 14
fi
: >  "$TMP_OUTPUT"
if [[ ! -e $TMP_OUTPUT ]]; then
    echo "$0: ERROR: cannot create output file: $TMP_OUTPUT" 1>&2
    exit 15
fi


# run the run.sh command on a remote server
#
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about run to: $SSH_RUN_SH -p $RMT_PORT -u $RMT_USER -H $SERVER -- $RMT_EMAIL_PR_PY -s u > $TMP_OUTPUT" 1>&2
    fi
    "$SSH_RUN_SH" -p "$RMT_PORT" -u "$RMT_USER" -H "$SERVER" -- "$RMT_EMAIL_PR_PY" -s u > "$TMP_OUTPUT"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: Warning: $SSH_RUN_SH -p $RMT_PORT -u $RMT_USER -H $SERVER -- $RMT_EMAIL_PR_PY -s u > $TMP_OUTPUT failed, error: $status" 1>&2
	exit 6
    fi
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not run: $SSH_RUN_SH -p $RMT_PORT -u $RMT_USER -H $SERVER -- $RMT_EMAIL_PR_PY -s u > $TMP_OUTPUT" 1>&2
fi


# do nothing if no email addresses were extracted
#
if [[ ! -s $TMP_OUTPUT ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: no email addresses found, nothing to do" 1>&2
    fi
    exit 0
fi


# move extracted email addresses to iocccpasswd.lst
#
if [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: about to run: mv -f $TMP_OUTPUT $IOCCCPASSWD_LST" 1>&2
fi
mv -f "$TMP_OUTPUT" "$IOCCCPASSWD_LST"
status="$?"
if [[ $status -ne 0 ]]; then
    echo "$0: ERROR: mv -f $TMP_OUTPUT $IOCCCPASSWD_LST failed, error: $status" 1>&2
    exit 1
fi


# All Done!!! All Done!!! -- Jessica Noll, Age 2
#
exit 0
