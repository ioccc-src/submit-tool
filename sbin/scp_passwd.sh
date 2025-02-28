#!/usr/bin/env bash
#
# scp_passwd.sh - remove copy IOCCC submit server IOCCC password file
#
# Copy the IOCCC submit server IOCCC password file to a local file.
# On the remote IOCCC submit server, the etc/iocccpasswd.json file
# is first copied into a remote temporary file while under lock,
# so that the IOCCC password file obtained is coherent (not in the
# middle of a file update).  Then that remote temporary file is copied
# to a local file.  Last, the remote temporary file is removed.
# Both the copy into a remote temporary file and the remote temporary file
# removal are logged in the remote server.
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
export VERSION="2.0.5 2025-02-27"
NAME=$(basename "$0")
export NAME
export V_FLAG=0
#
export NOOP=
export DO_NOT_PROCESS=
#
export RMT_TOPDIR
if [[ -z $RMT_TOPDIR ]]; then
    RMT_TOPDIR="/var/spool/ioccc"
fi
#
export RMT_TMPDIR
if [[ -z $RMT_TMPDIR ]]; then
    RMT_TMPDIR="/tmp"
fi
#
export IOCCC_RC
if [[ -z $IOCCC_RC ]]; then
    IOCCC_RC="$HOME/.ioccc.rc"
fi
#
export CAP_I_FLAG=
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
    SSH_RUN_SH=$(type -P ssh_run.sh)
    if [[ -z "$SSH_RUN_SH" ]]; then
	echo "$0: FATAL: ssh_run.sh tool is not installed or not in \$PATH" 1>&2
	exit 5
    fi
fi
#
export SCP_TOOL
if [[ -z $SCP_TOOL ]]; then
    SCP_TOOL=$(type -P scp)
    if [[ -z "$SCP_TOOL" ]]; then
	echo "$0: FATAL: scp tool is not installed or not in \$PATH" 1>&2
	exit 5
    fi
fi
#
export RMT_CP_PASSWD_PY
if [[ -z $RMT_CP_PASSWD_PY ]]; then
    RMT_CP_PASSWD_PY="/usr/ioccc/bin/cp_passwd.py"
fi
#
export RMT_LOGGER
if [[ -z $RMT_LOGGER ]]; then
    RMT_LOGGER="/usr/local/bin/loggger"
fi
#
export RMT_LOG_LEVEL
if [[ -z $RMT_LOG_LEVEL ]]; then
    RMT_LOG_LEVEL="debug"
fi


# usage
#
export USAGE="usage: $0 [-h] [-v level] [-V] [-n] [-N] [-t rmt_topdir] [-T rmt_tmpdir] [-i ioccc.rc] [-I]
	[-p rmt_port] [-u rmt_user] [-H rmt_host] [-s ssh_run] [-c scp_tool] [-P rmt_cp_passwd]
	[-l rmt_logger] [-L log_level]
	newfile

	-h		print help message and exit
	-v level	set verbosity level (def level: 0)
	-V		print version string and exit

	-n		go thru the actions, but do not update any files (def: do the action)
	-N		do not process anything, just parse arguments (def: process something)

	-t rmt_topdir   app directory path on server (def: $RMT_TOPDIR)
	-T rmt_tmpdir	form remote temp files under tmpdir (def: $RMT_TMPDIR)

	-i ioccc.rc	Use ioccc.rc as the rc startup file (def: $IOCCC_RC)
	-I		Do not use any rc startup file (def: do)

	-p rmt_port	use ssh TCP port (def: $RMT_PORT)
	-u rmt_user	ssh into this user (def: $RMT_USER)
	-H rmt_host	ssh host to use (def: $SERVER)

	-s ssh_run	use local ssh_run to ssh (def: $SSH_RUN_SH)
	-c scp_tool	use local scp_tool to scp (def: $SCP_TOOL)

	-P rmt_cp_passwd    path to cp_passwd.py on the remote server (def: $RMT_CP_PASSWD_PY)
	-l rmt_logger	    path to logger command on the remote server (def: $RMT_LOGGER)
	-L log_level	    logging level given to the rmt_logger command (def: $RMT_LOG_LEVEL)

	newfile		copy submit server password file to newfile

Exit codes:
     0        all OK
     1	      copy failed
     2        -h and help string printed or -V and version string printed
     3        command line error
     4        source of ioccc.rc file failed
     5        some critical local executable tool not found
     6        remote execution of a tool failed, returned an exit code, or returned a malformed response
     7	      removal of remote tmp file failed
     8        scp of remote file(s) or ssh rm -f of file(s) failed

 >= 10        internal error

$NAME version: $VERSION"


# parse command line
#
while getopts :hv:VnNt:T:iIp:u:H:s:c:P:l:L: flag; do
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
    t) RMT_TOPDIR="$OPTARG"
	;;
    T) RMT_TMPDIR="$OPTARG"
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
    c) SCP_TOOL="$OPTARG"
	;;
    P) RMT_CP_PASSWD_PY="$OPTARG"
	;;
    l) RMT_LOGGER="$OPTARG"
	;;
    L) RMT_LOG_LEVEL="$OPTARG"
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
export NEWFILE="$1"


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


# guess at a remove temporary filename
#
export RMT_TMPFILE="$RMT_TMPDIR/.tmp.$NAME.TMPFILE.$$.tmp"


# firewall - SSH_RUN_SH must be executable
#
if [[ ! -x $SSH_RUN_SH ]]; then
    echo "$0: ERROR: ssh_run.sh tool not executable: $SSH_RUN_SH" 1>&2
    exit 5
fi


# firewall - SCP_TOOL must be executable
#
if [[ ! -x $SCP_TOOL ]]; then
    echo "$0: ERROR: scp tool not executable: $SCP_TOOL" 1>&2
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
    echo "$0: debug[3]: RMT_TOPDIR=$RMT_TOPDIR" 1>&2
    echo "$0: debug[3]: RMT_TMPDIR=$RMT_TMPDIR" 1>&2
    echo "$0: debug[3]: IOCCC_RC=$IOCCC_RC" 1>&2
    echo "$0: debug[3]: CAP_I_FLAG=$CAP_I_FLAG" 1>&2
    echo "$0: debug[3]: RMT_PORT=$RMT_PORT" 1>&2
    echo "$0: debug[3]: RMT_USER=$RMT_USER" 1>&2
    echo "$0: debug[3]: SERVER=$SERVER" 1>&2
    echo "$0: debug[3]: SSH_RUN_SH=$SSH_RUN_SH" 1>&2
    echo "$0: debug[3]: SCP_TOOL=$SCP_TOOL" 1>&2
    echo "$0: debug[3]: RMT_CP_PASSWD_PY=$RMT_CP_PASSWD_PY" 1>&2
    echo "$0: debug[3]: RMT_LOGGER=$RMT_LOGGER" 1>&2
    echo "$0: debug[3]: RMT_LOG_LEVEL=$RMT_LOG_LEVEL" 1>&2
    echo "$0: debug[3]: NEWFILE=$NEWFILE" 1>&2
    echo "$0: debug[3]: RMT_TMPFILE=$RMT_TMPFILE" 1>&2
fi


# -N stops early before any processing is performed
#
if [[ -n $DO_NOT_PROCESS ]]; then
    if [[ $V_FLAG -ge 3 ]]; then
	echo "$0: debug[3]: arguments parsed, -N given, exiting 0" 1>&2
    fi
    exit 0
fi


# ssh to remove server to run RMT_CP_PASSWD_PY to copy the submit server IOCCC password file to a remote temp file
#
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: $SSH_RUN_SH $RMT_CP_PASSWD_PY $RMT_TMPFILE >/dev/null" 1>&2
    fi
    "$SSH_RUN_SH" "$RMT_CP_PASSWD_PY" "$RMT_TMPFILE" >/dev/null
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: Warning: $SSH_RUN_SH $RMT_CP_PASSWD_PY $RMT_TMPFILE >/dev/null failed, error: $status" 1>&2
	exit 6
    fi
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not run: $SSH_RUN_SH $RMT_CP_PASSWD_PY $RMT_TMPFILE >/dev/null" 1>&2
fi


# scp the copy the submit server IOCCC password in a remote temp file to the local newfile
#
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: $SCP_TOOL -P $RMT_PORT $RMT_USER@$SERVER:$RMT_TMPFILE $NEWFILE" 1>&2
    fi
    "$SCP_TOOL" -q -P "$RMT_PORT" "$RMT_USER@$SERVER:$RMT_TMPFILE" "$NEWFILE"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: Warning: $SCP_TOOL -q -P $RMT_PORT $RMT_USER@$SERVER:$RMT_TMPFILE $NEWFILE failed, error: $status" 1>&2
    fi
    if [[ ! -r $NEWFILE ]]; then
	# We have no remote file - we can do thing more at this stage
	echo "$0: ERROR: destination file not found: $NEWFILE" 1>&2
	exit 8
    fi
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not run: $SCP_TOOL -P $RMT_PORT $RMT_USER@$SERVER:$RMT_TMPFILE $NEWFILE" 1>&2
fi


# remove the remote temp file
#
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: $SSH_RUN_SH /bin/rm -f $RMT_TMPFILE" 1>&2
    fi
    "$SSH_RUN_SH" /bin/rm -f "$RMT_TMPFILE" >/dev/null
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: Warning: $SSH_RUN_SH /bin/rm -f $RMT_TMPFILE failed, error: $status" 1>&2
	exit 7
    fi
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not run: $SSH_RUN_SH /bin/rm -f $RMT_TMPFILE" 1>&2
fi


# log the removal of the remote temp file for audio purposes
#
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: $SSH_RUN_SH $RMT_LOGGER --priority $RMT_LOG_LEVEL 'removed $RMT_TMPFILE' >/dev/null" 1>&2
    fi
    "$SSH_RUN_SH" "$RMT_LOGGER" --priority "$RMT_LOG_LEVEL" "'removed $RMT_TMPFILE'" >/dev/null
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: Warning: $SSH_RUN_SH $RMT_LOGGER --priority $RMT_LOG_LEVEL 'removed $RMT_TMPFILE' failed, error: $status" 1>&2
	exit 6
    fi
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not run: $SSH_RUN_SH $RMT_LOGGER --priority $RMT_LOG_LEVEL 'removed $RMT_TMPFILE'" 1>&2
fi



# All Done!!! All Done!!! -- Jessica Noll, Age 2
#
exit 0
