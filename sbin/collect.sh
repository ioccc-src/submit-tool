#!/usr/bin/env bash
#
# collect.sh - remotely stage a submit file and collect it
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
export VERSION="2.1.1 2025-02-06"
NAME=$(basename "$0")
export NAME
export V_FLAG=0
#
export NOOP=
export DO_NOT_PROCESS=
#
export REMOTE_TOPDIR="/var/spool/ioccc"
export IOCCC_RC="$HOME/.ioccc.rc"
export CAP_I_FLAG=
export REMOTE_PORT=22
export REMOTE_USER="nobody"
if [[ -n $USER_NAME ]]; then
    REMOTE_USER="$USER_NAME"
else
    USER_NAME=$(id -u -n)
    if [[ -n $USER_NAME ]]; then
	REMOTE_USER="$USER_NAME"
    fi
fi
export SERVER="unknown.example.org"
export RMT_STAGE_PY="/usr/ioccc/bin/stage.py"
export RMT_SET_SLOT_STATUS_PY="/usr/ioccc/bin/set_slot_status.py"
SSH_TOOL=$(type -P ssh)
export SSH_TOOL
if [[ -z "$SSH_TOOL" ]]; then
    echo "$0: FATAL: ssh tool is not installed or not in \$PATH" 1>&2
    exit 5
fi
SCP_TOOL=$(type -P scp)
export SCP_TOOL
if [[ -z "$SCP_TOOL" ]]; then
    echo "$0: FATAL: scp tool is not installed or not in \$PATH" 1>&2
    exit 5
fi
SHA256_TOOL=$(type -P sha256sum)
export SHA256_TOOL
if [[ -z "$SHA256_TOOL" ]]; then
    echo "$0: FATAL: sha256sum tool is not installed or not in \$PATH" 1>&2
    exit 5
fi
RSYNC_TOOL=$(type -P rsync)
export RSYNC_TOOL
if [[ -z "$RSYNC_TOOL" ]]; then
    echo "$0: FATAL: rsync tool is not installed or not in \$PATH" 1>&2
    exit 5
fi
TXZCHK_TOOL=$(type -P txzchk)
export TXZCHK_TOOL
if [[ -z "$TXZCHK_TOOL" ]]; then
    echo "$0: FATAL: txzchk tool is not installed or not in \$PATH" 1>&2
    exit 5
fi
CHKENTRY_TOOL=$(type -P chkentry)
export CHKENTRY_TOOL
if [[ -z "$CHKENTRY_TOOL" ]]; then
    echo "$0: FATAL: chkentry tool is not installed or not in \$PATH" 1>&2
    exit 5
fi
XZ_TOOL=$(type -P xz)
export XZ_TOOL
if [[ -z "$XZ_TOOL" ]]; then
    echo "$0: FATAL: xz tool is not installed or not in \$PATH" 1>&2
    exit 5
fi
export WORKDIR="."


# usage
#
export USAGE="usage: $0 [-h] [-v level] [-V] [-n] [-N] [-t rmt_topdir] [-i ioccc.rc] [-I]
	[-p rmt_port] [-u rmt_user] [-s rmt_host]
	[-T ssh_tool] [-c scp_tool] [-s sha256_tool] [-r rsync_root] [-x xz]
	[-z txzchk] [-y chkenry]
	[-S rmt_stage] [-C slot_comment] [-w workdir]
	rmt_slot_path

	-h		print help message and exit
	-v level	set verbosity level (def level: 0)
	-V		print version string and exit

	-n		go thru the actions, but do not update any files (def: do the action)
	-N		do not process anything, just parse arguments (def: process something)

	-t rmt_topdir   app directory path on server (def: $REMOTE_TOPDIR)

	-i ioccc.rc	Use ioccc.rc as the rc startup file (def: $IOCCC_RC)
	-I		Do not use any rc startup file (def: do)

	-p rmt_port	use ssh TCP port (def: $REMOTE_PORT)
	-u rmt_user	ssh into this user (def: $REMOTE_USER)
	-s rmt_host	ssh host to use (def: $SERVER)

	-T ssh_tool	use local ssh_tool to ssh (def: $SSH_TOOL)
	-c scp_tool	use local scp_tool to scp (def: $SCP_TOOL)
	-2 sha256_tool	use local sha256_tool to hash (def: $SHA256_TOOL)
	-r rsync_root	use local rsync tool to sync trees (def: $RSYNC_TOOL)
	-x xz		use local xz tool to compress (def: $XZ_TOOL)

	-z txzchk	use local txzchk tool to test compressed tarballs (def: $TXZCHK_TOOL)
	-y chkenry	use local chkenry tool to test unpacked submission (def: $CHKENTRY_TOOL)

	-S rmt_stage	path to stage.py on the remote server (def: $RMT_STAGE_PY)
	-C slot_comment	path to set_slot_status.py on the remote server (def: $RMT_SET_SLOT_STATUS_PY)

	-w workdir	cd to the workdir before running (def: stay in $WORKDIR)

	rmt_slot_path	The path on the remote side, of the slot to process

	NOTE: The slot_path can be relative to the rmt_topdir

Exit codes:
     0         all OK
     1	       some internal tool is missing or exited non-zero
     2         -h and help string printed or -V and version string printed
     3         command line error
     4	       source of ioccc.rc file failed
     5	       some critical local executable tool not found
     6	       remote execution of a tool failed, returned an exit code, or returned a malformed response
     7	       inbound and/or error are not writable directories, or workdir is not a directory
     8	       scp of remote file(s) or ssh rm -f of file(s) failed
     9	       downloaded file failed local tests
 >= 10         internal error

$NAME version: $VERSION"


# parse command line
#
while getopts :hv:VnNi:Ip:u:s:T:c:2:r:x:z:y:S:C:w: flag; do
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
    i) IOCCC_RC="$OPTARG"
	;;
    I) CAP_I_FLAG="true"
	;;
    p) REMOTE_PORT="$OPTARG"
	;;
    u) REMOTE_USER="$OPTARG"
	;;
    s) SERVER="$OPTARG"
	;;
    T) SSH_TOOL="$OPTARG"
	;;
    c) SCP_TOOL="$OPTARG"
	;;
    2) SHA256_TOOL="$OPTARG"
	;;
    r) RSYNC_TOOL="$OPTARG"
	;;
    x) XZ_TOOL="$OPTARG"
	;;
    z) TXZCHK_TOOL="$OPTARG"
	;;
    y) CHKENTRY_TOOL="$OPTARG"
	;;
    S) RMT_STAGE_PY="$OPTARG"
	;;
    C) RMT_SET_SLOT_STATUS_PY="$OPTARG"
	;;
    w) WORKDIR="$OPTARG"
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
RMT_SLOT_PATH="$1"


# determine the username and slot_num of the slot path
#
SLOT_NUM=$(basename "$RMT_SLOT_PATH")
export SLOT_NUM
RMT_SLOT_DIRNAME=$(dirname "$RMT_SLOT_PATH")
USERNAME=$(basename "$RMT_SLOT_DIRNAME")
export USERNAME


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
    echo "$0: debug[3]: REMOTE_TOPDIR=$REMOTE_TOPDIR" 1>&2
    echo "$0: debug[3]: IOCCC_RC=$IOCCC_RC" 1>&2
    echo "$0: debug[3]: REMOTE_PORT=$REMOTE_PORT" 1>&2
    echo "$0: debug[3]: REMOTE_USER=$REMOTE_USER" 1>&2
    echo "$0: debug[3]: SERVER=$SERVER" 1>&2
    echo "$0: debug[3]: SSH_TOOL=$SSH_TOOL" 1>&2
    echo "$0: debug[3]: SCP_TOOL=$SCP_TOOL" 1>&2
    echo "$0: debug[3]: SHA256_TOOL=$SHA256_TOOL" 1>&2
    echo "$0: debug[3]: RSYNC_TOOL=$RSYNC_TOOL" 1>&2
    echo "$0: debug[3]: XZ_TOOL=$XZ_TOOL" 1>&2
    echo "$0: debug[3]: TXZCHK_TOOL=$TXZCHK_TOOL" 1>&2
    echo "$0: debug[3]: CHKENTRY_TOOL=$CHKENTRY_TOOL" 1>&2
    echo "$0: debug[3]: RMT_STAGE_PY=$RMT_STAGE_PY" 1>&2
    echo "$0: debug[3]: RMT_SET_SLOT_STATUS_PY=$RMT_SET_SLOT_STATUS_PY" 1>&2
    echo "$0: debug[3]: WORKDIR=$WORKDIR" 1>&2
    echo "$0: debug[3]: RMT_SLOT_PATH=$RMT_SLOT_PATH" 1>&2
    echo "$0: debug[3]: SLOT_NUM=$SLOT_NUM" 1>&2
    echo "$0: debug[3]: USERNAME=$USERNAME" 1>&2
fi


# firewall - SSH_TOOL must be executable
#
if [[ ! -x $SSH_TOOL ]]; then
    echo "$0: ERROR: ssh tool not executable: $SSH_TOOL" 1>&2
    exit 5
fi


# firewall - SCP_TOOL must be executable
#
if [[ ! -x $SCP_TOOL ]]; then
    echo "$0: ERROR: scp tool not executable: $SCP_TOOL" 1>&2
    exit 5
fi


# firewall - SHA256_TOOL must be executable
#
if [[ ! -x $SHA256_TOOL ]]; then
    echo "$0: ERROR: sha256sum tool not executable: $SHA256_TOOL" 1>&2
    exit 5
fi


# firewall - RSYNC_TOOL must be executable
#
if [[ ! -x $RSYNC_TOOL ]]; then
    echo "$0: ERROR: rsync tool not executable: $RSYNC_TOOL" 1>&2
    exit 5
fi


# firewall - XZ_TOOL must be executable
#
if [[ ! -x $XZ_TOOL ]]; then
    echo "$0: ERROR: xz tool not executable: $XZ_TOOL" 1>&2
    exit 5
fi


# firewall - TXZCHK_TOOL must be executable
#
if [[ ! -x $TXZCHK_TOOL ]]; then
    echo "$0: ERROR: txzchk tool not executable: $TXZCHK_TOOL" 1>&2
    exit 5
fi


# firewall - CHKENTRY_TOOL must be executable
#
if [[ ! -x $CHKENTRY_TOOL ]]; then
    echo "$0: ERROR: chkentry tool not executable: $CHKENTRY_TOOL" 1>&2
    exit 5
fi


# firewall - workdir must be a directory
#
if [[ ! -d $WORKDIR ]]; then
    echo "$0: ERROR: workdir is not a directory: $WORKDIR" 1>&2
    exit 7
fi


# move to workdir is workdir is not .
#
if [[ $WORKDIR != "." ]]; then
    if [[ $V_FLAG -ge 3 ]]; then
	echo "$0: debug[3]: about to cd $WORKDIR" 1>&2
    fi
    export CD_FAILED=""
    cd "$WORKDIR" || CD_FAILED="true"
    if [[ -n $CD_FAILED ]]; then
	echo "$0: ERROR: cd $WORKDIR failed" 1>&2
	exit 7
    fi
fi


# firewall - current directory must contain inbound and error as writable directories
#
export INBOUND="inbound"
if [[ ! -d $INBOUND || ! -w $INBOUND ]]; then
    echo "$0: ERROR: inbound is not a writable directory under workdir" 1>&2
    exit 7
fi
export ERRORS="errors"
if [[ ! -d $ERRORS || ! -w $ERRORS ]]; then
    echo "$0: ERROR: errors is not a writable directory under workdir" 1>&2
    exit 7
fi
export SUBMIT="submit"
if [[ ! -d $SUBMIT || ! -w $SUBMIT ]]; then
    echo "$0: ERROR: submit is not a writable directory under workdir" 1>&2
    exit 7
fi


# -N stops early before any processing is performed
#
if [[ -n $DO_NOT_PROCESS ]]; then
    if [[ $V_FLAG -ge 3 ]]; then
	echo "$0: debug[3]: arguments parsed, -N given, exiting 0" 1>&2
    fi
    exit 0
fi


# run the remote stage.py tool via ssh, on the remote server, and collect the reply
#
if [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: about to: $SSH_TOOL -n -p $REMOTE_PORT $REMOTE_USER@$SERVER $RMT_STAGE_PY $RMT_SLOT_PATH" 1>&2
fi
if [[ -z $NOOP ]]; then
    ANSWER=$("$SSH_TOOL" -n -p "$REMOTE_PORT" "$REMOTE_USER@$SERVER" "$RMT_STAGE_PY" "$RMT_SLOT_PATH")
    status="$?"
else
    ANSWER="exit.0 . 0"
    status=0
fi
if [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: stage.py returned: $ANSWER" 1>&2
fi
if [[ $status -ne 0 ]]; then
    echo "$0: ERROR: $SSH_TOOL -n -p $REMOTE_PORT $REMOTE_USER@$SERVER $RMT_STAGE_PY $RMT_SLOT_PATH failed, error: $status" 1>&2
    exit 6
fi


# parse answer from remote stage.py tool
#
if [[ -z $ANSWER ]]; then
    echo "$0: ERROR: $RMT_STAGE_PY $RMT_SLOT_PATH answer was empty" 1>&2
    exit 6
fi
read -r HEXDIGEST STAGED_PATH UNEXPECTED_COUNT EXTRA <<< "$ANSWER"
if [[ -z $HEXDIGEST ]]; then
    echo "$0: ERROR: $RMT_STAGE_PY $RMT_SLOT_PATH 1st field of answer, HEXDIGEST was empty" 1>&2
    exit 6
fi
if [[ -z $STAGED_PATH ]]; then
    echo "$0: ERROR: $RMT_STAGE_PY $RMT_SLOT_PATH 2nd field of answer, STAGED_PATH was empty" 1>&2
    exit 6
fi
if [[ -z $UNEXPECTED_COUNT ]]; then
    echo "$0: ERROR: $RMT_STAGE_PY $RMT_SLOT_PATH 3rd field of answer, UNEXPECTED_COUNT was empty" 1>&2
    exit 6
fi
if [[ -n $EXTRA ]]; then
    echo "$0: ERROR: $RMT_STAGE_PY $RMT_SLOT_PATH had 4 or more fields, expected only 3" 1>&2
    exit 6
fi
if [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: HEXDIGEST: $HEXDIGEST" 1>&2
    echo "$0: debug[3]: STAGED_PATH: $STAGED_PATH" 1>&2
    echo "$0: debug[3]: UNEXPECTED_COUNT: $UNEXPECTED_COUNT" 1>&2
fi


# case: remote stage.py tool exited with an error
#
# When the remote stage.py tool as a failure, it will exit with a exit.code.  For example:
#
#   exit.4
#
# This indicates that the stage.py tool called sys.exit(6).
#
if [[ $HEXDIGEST == exit.* ]]; then
    EXIT_CODE=${HEXDIGEST#exit.*}
    if [[ -z $EXIT_CODE ]]; then
	echo "$0: ERROR: $RMT_STAGE_PY $RMT_SLOT_PATH HEXDIGEST stats with exit. but lacks code: $HEXDIGEST" 1>&2
	exit 6
    fi
    if [[ $EXIT_CODE =~ ^[0-9]+$ ]]; then
	echo "$0: ERROR: $RMT_STAGE_PY $RMT_SLOT_PATH exited non-zero: exit.$EXIT_CODE $STAGED_PATH $UNEXPECTED_COUNT" 1>&2
	exit 6
    fi
fi


# firewall - now that the exit.code has been taken care of, verify HEXDIGEST is a SHA256 hex digest
#
if ! [[ $HEXDIGEST =~ ^[0-9a-f]+$ || ${#HEXDIGEST} -ne 64 ]]; then
    echo "$0: ERROR: $RMT_STAGE_PY $RMT_SLOT_PATH HEXDIGEST is neither exit.code not SHA256 hash: $HEXDIGEST" 1>&2
    exit 6
fi


# firewall - STAGED_PATH cannot be .
#
# When the remote stage.py tool ran into critical error that prevented it from moving the submit file
# under the staged directory, a STAGED_PATH of "." is returned.  Normally such a condition would have
# come with a HEXDIGEST of the form exit.code.  Just in case the HEXDIGEST is a SHA256 SHA256 hex digest,
# we deal with a "." STAGED_PATH here.
#
if [[ $STAGED_PATH == "." ]]; then
    echo "$0: ERROR: $RMT_STAGE_PY $RMT_SLOT_PATH  is ." 1>&2
    exit 6
fi


# determine scp destination, filename, and submit directory
#
STAGED_FILENAME=$(basename "$STAGED_PATH")
export STAGED_FILENAME
STAGED_FILENAME_NOTXZ=$(basename "$STAGED_PATH" .txz)
export STAGED_FILENAME_NOTXZ
DEST="$INBOUND/$STAGED_FILENAME"
export DEST
SUBMIT_TIME=${STAGED_FILENAME##submit.}
SUBMIT_FILENAME=${SUBMIT_TIME%%.txz}
export SUBMIT_FILENAME
SUBMIT_TIME=${SUBMIT_FILENAME##*.}
export SUBMIT_TIME
SUBMIT_USERSLOT=${SUBMIT_FILENAME%%."$SUBMIT_TIME"}
export SUBMIT_USERSLOT
if [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: STAGED_FILENAME=$STAGED_FILENAME" 1>&2
    echo "$0: debug[3]: STAGED_FILENAME_NOTXZ=$STAGED_FILENAME_NOTXZ" 1>&2
    echo "$0: debug[3]: DEST=$DEST" 1>&2
    echo "$0: debug[3]: SUBMIT_TIME=$SUBMIT_TIME" 1>&2
    echo "$0: debug[3]: SUBMIT_FILENAME=$SUBMIT_FILENAME" 1>&2
    echo "$0: debug[3]: SUBMIT_TIME=$SUBMIT_TIME" 1>&2
    echo "$0: debug[3]: SUBMIT_USERSLOT=$SUBMIT_USERSLOT" 1>&2
fi


# remote copy of staged path into the inbound directory
#
if [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: about to: $SCP_TOOL -P $REMOTE_PORT $REMOTE_USER@$SERVER:$STAGED_PATH $DEST" 1>&2
fi
if [[ -z $NOOP ]]; then

    # copy remote staged file
    #
    "$SCP_TOOL" -q -P "$REMOTE_PORT" "$REMOTE_USER@$SERVER:$STAGED_PATH" "$DEST"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: $SCP_TOOL -q -P $REMOTE_PORT $REMOTE_USER@$SERVER:$STAGED_PATH $DEST failed, error: $status" 1>&2
	exit 8
    fi
    if [[ ! -r $DEST ]]; then
	echo "$0: ERROR: $SCP_TOOL destination not found: $DEST" 1>&2
	exit 8
    fi

    # verify SHA256 hex digest
    #
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: $SHA256_TOOL $DEST" 1>&2
    fi
    # remove filename from SHA256_TOOL output leaving just the SHA256 hex digest
    DEST_HEXDIGEST=$("$SHA256_TOOL" "$DEST")
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: $SHA256_TOOL $DEST failed, error: $status" 1>&2
	exit 8
    fi
    DEST_HEXDIGEST=${DEST_HEXDIGEST%% *}
    if [[ $V_FLAG -ge 3 ]]; then
	echo "$0: debug[3]: $SHA256_TOOL $DEST: $DEST_HEXDIGEST" 1>&2
    fi
    if [[ $DEST_HEXDIGEST != "$HEXDIGEST" ]]; then
	echo "$0: ERROR: $DEST SHA256 hash: $DEST_HEXDIGEST != remote SHA256 hash: $HEXDIGEST" 1>&2
	exit 8
    fi

    # update the slot comment on the remote server
    #
    COMMENT="submit file fetched by an IOCCC judge prior to format testing"
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: $SSH_TOOL -n -p $REMOTE_PORT $REMOTE_USER@$SERVER $RMT_SET_SLOT_STATUS_PY $USERNAME $SLOT_NUM '$COMMENT' > /dev/null" 1>&2
    fi
    "$SSH_TOOL" -n -p "$REMOTE_PORT" "$REMOTE_USER@$SERVER" "$RMT_SET_SLOT_STATUS_PY" "$USERNAME" "$SLOT_NUM" "'$COMMENT'" >/dev/null
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: $SSH_TOOL -n -p $REMOTE_PORT $REMOTE_USER@$SERVER $RMT_SET_SLOT_STATUS_PY $USERNAME $SLOT_NUM '$COMMENT' > /dev/null failed, error: $status" 1>&2
	exit 6
    fi

    # remove the remote staged file
    #
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: $SSH_TOOL -n -p $REMOTE_PORT $REMOTE_USER@$SERVER rm -f $STAGED_PATH" 1>&2
    fi
    "$SSH_TOOL" -n -p "$REMOTE_PORT" "$REMOTE_USER@$SERVER" rm -f "$STAGED_PATH"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: $SSH_TOOL -n -p $REMOTE_PORT $REMOTE_USER@$SERVER rm -f $STAGED_PATH failed, error: $status" 1>&2
	exit 8
    fi

    # test the destination file using txzchk
    #
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: $TXZCHK_TOOL -q $DEST" 1>&2
    fi
    "$TXZCHK_TOOL" -q "$DEST"
    status="$?"
    if [[ $status -ne 0 ]]; then

	# report txzchk test failure
	#
	echo "$0: ERROR: $TXZCHK_TOOL -q $DEST failed, error: $status" 1>&2

	# update the slot comment with the txzchk failure
	#
	COMMENT="submit file failed the txxchk test!  Use mkiocccentry to rebuild and resubmit to this slot."
	if [[ $V_FLAG -ge 1 ]]; then
	    echo "$0: debug[1]: about to: $SSH_TOOL -n -p $REMOTE_PORT $REMOTE_USER@$SERVER $RMT_SET_SLOT_STATUS_PY $USERNAME $SLOT_NUM '$COMMENT' > /dev/null" 1>&2
	fi
	"$SSH_TOOL" -n -p "$REMOTE_PORT" "$REMOTE_USER@$SERVER" "$RMT_SET_SLOT_STATUS_PY" "$USERNAME" "$SLOT_NUM" "'$COMMENT'" >/dev/null
	status="$?"
	if [[ $status -ne 0 ]]; then
	    echo "$0: ERROR: $SSH_TOOL -n -p $REMOTE_PORT $REMOTE_USER@$SERVER $RMT_SET_SLOT_STATUS_PY $USERNAME $SLOT_NUM '$COMMENT' > /dev/null failed, error: $status" 1>&2
	    exit 6
	fi

	# move destination file into errors
	#
	if [[ $V_FLAG -ge 1 ]]; then
	    echo "$0: debug[1]: about to: mv -v -f $DEST $ERRORS" 1>&2
	fi
	mv -v -f "$DEST" "$ERRORS"
	status="$?"
	if [[ $status -ne 0 ]]; then
	    echo "$0: ERROR: mv -v -f $DEST $ERRORS failed, error: $status" 1>&2
	    exit 6
	fi

	# exit non-zero due to txzchk failure
	#
	exit 9
    fi

    # create submission directory
    #
    export SUBMIT_PARENT_DIR="$SUBMIT/$SUBMIT_USERSLOT"
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: mkdir -p $SUBMIT_PARENT_DIR" 1>&2
    fi
    mkdir -p "$SUBMIT_PARENT_DIR"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: mkdir -p $SUBMIT_PARENT_DIR failed, error: $status" 1>&2
	exit 6
    fi
    if [[ ! -d $SUBMIT_PARENT_DIR ]]; then
	echo "$0: ERROR: mkdir -p $SUBMIT_PARENT_DIR did not create the directory" 1>&2
	exit 6
    fi

    # create tarball holding directory
    #
    export SUBMIT_TARBALL_DIR="$SUBMIT/$SUBMIT_USERSLOT/txz"
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: mkdir -p $SUBMIT_TARBALL_DIR" 1>&2
    fi
    mkdir -p "$SUBMIT_TARBALL_DIR"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: mkdir -p $SUBMIT_TARBALL_DIR failed, error: $status" 1>&2
	exit 6
    fi
    if [[ ! -d $SUBMIT_TARBALL_DIR ]]; then
	echo "$0: ERROR: mkdir -p $SUBMIT_TARBALL_DIR did not create the directory" 1>&2
	exit 6
    fi

    # create a new temporary unpack directory
    #
    export SUBMIT_UNPACK_DIR="$SUBMIT_PARENT_DIR/tmp.$$"
    trap 'rm -rf $SUBMIT_UNPACK_DIR; exit' 0 1 2 3 15
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: mkdir -p $SUBMIT_UNPACK_DIR" 1>&2
    fi
    mkdir -p "$SUBMIT_UNPACK_DIR"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: mkdir -p $SUBMIT_UNPACK_DIR failed, error: $status" 1>&2
	exit 6
    fi
    if [[ ! -d $SUBMIT_UNPACK_DIR ]]; then
	echo "$0: ERROR: mkdir -p $SUBMIT_UNPACK_DIR did not create the directory" 1>&2
	exit 6
    fi

    # untar the submit file under the new temporary directory
    #
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: tar -C $SUBMIT_UNPACK_DIR -Jxf $DEST"
    fi
    tar -C "$SUBMIT_UNPACK_DIR" -Jxf "$DEST"
    status="$?"
    if [[ $status -ne 0 ]]; then

	# report untar failure
	#
	echo "$0: ERROR: tar -C $SUBMIT_UNPACK_DIR -Jxf $DEST failed, error: $status" 1>&2

	# update the slot comment with the txzchk failure
	#
	COMMENT="submit file failed to untar!  Use mkiocccentry to rebuild and resubmit to this slot."
	if [[ $V_FLAG -ge 1 ]]; then
	    echo "$0: debug[1]: about to: $SSH_TOOL -n -p $REMOTE_PORT $REMOTE_USER@$SERVER $RMT_SET_SLOT_STATUS_PY $USERNAME $SLOT_NUM '$COMMENT' > /dev/null" 1>&2
	fi
	"$SSH_TOOL" -n -p "$REMOTE_PORT" "$REMOTE_USER@$SERVER" "$RMT_SET_SLOT_STATUS_PY" "$USERNAME" "$SLOT_NUM" "'$COMMENT'" >/dev/null
	status="$?"
	if [[ $status -ne 0 ]]; then
	    echo "$0: ERROR: $SSH_TOOL -n -p $REMOTE_PORT $REMOTE_USER@$SERVER $RMT_SET_SLOT_STATUS_PY $USERNAME $SLOT_NUM '$COMMENT' > /dev/null failed, error: $status" 1>&2
	    exit 6
	fi

	# move destination file into errors
	#
	if [[ $V_FLAG -ge 1 ]]; then
	    echo "$0: debug[1]: about to: mv -v -f $DEST $ERRORS" 1>&2
	fi
	mv -v -f "$DEST" "$ERRORS"
	status="$?"
	if [[ $status -ne 0 ]]; then
	    echo "$0: ERROR: mv -v -f $DEST $ERRORS failed, error: $status" 1>&2
	    exit 6
	fi

	# exit non-zero due to txzchk failure
	#
	exit 9
    fi

    # find a brand new place into which to move the temporary tree
    #
    export SUBMIT_DIR="$SUBMIT_PARENT_DIR/$SUBMIT_TIME"
    if [[ -e $SUBMIT_DIR ]]; then

	# we already have SUBMIT_DIR, find a different directory that does NOT already exist
	#
	((i=0))
	SUBMIT_DIR="$SUBMIT_PARENT_DIR/$SUBMIT_TIME.$i"
	while [[ -e $SUBMIT_DIR ]]; do
	    ((i=i+1))
	    SUBMIT_DIR="$SUBMIT_PARENT_DIR/$SUBMIT_TIME.$i"
	done
    fi
    if [[ $V_FLAG -ge 3 ]]; then
	echo "$0: debug[3]: SUBMIT_DIR=$SUBMIT_DIR" 1>&2
    fi

    # move the temporary unpacked tree into place
    #
    if [[ $V_FLAG -ge 3 ]]; then
	echo "$0: debug[3]: will move unpacked into: $SUBMIT_DIR" 1>&2
    fi
    SRC_DIR=$(find "$SUBMIT_UNPACK_DIR" -mindepth 1 -maxdepth 1 -type d)
    export SRC_DIR
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: mv -f $SRC_DIR $SUBMIT_DIR" 1>&2
    fi
    mv -f "$SRC_DIR" "$SUBMIT_DIR"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: mv -f $SRC_DIR $SUBMIT_DIR failed, error: $status" 1>&2
	exit 6
    fi
    if [[ ! -d $SUBMIT_DIR ]]; then
	echo "$0: ERROR: mv -f $SRC_DIR $SUBMIT_DIR did not create the directory" 1>&2
	exit 6
    fi

    # find a destination tarball under the SUBMIT_TARBALL_DIR directory
    #
    DEST_TARBALL="$SUBMIT_TARBALL_DIR/$STAGED_FILENAME"
    if [[ -e $DEST_TARBALL ]]; then

	# we already have a DEST_TARBALL, find a different filename that does NOT already exist
	#
	((i=0))
	DEST_TARBALL="$SUBMIT_TARBALL_DIR/$STAGED_FILENAME_NOTXZ.$i.txz"
	while [[ -e $DEST_TARBALL ]]; do
	    ((i=i+1))
	    DEST_TARBALL="$SUBMIT_TARBALL_DIR/$STAGED_FILENAME_NOTXZ.$i.txz"
	done
    fi
    if [[ $V_FLAG -ge 3 ]]; then
	echo "$0: debug[3]: DEST_TARBALL=$DEST_TARBALL" 1>&2
    fi

    # move the inbound tarball under the SUBMIT_TARBALL_DIR
    #
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: mv -f $DEST $DEST_TARBALL" 1>&2
    fi
    mv -f "$DEST" "$DEST_TARBALL"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: mv -f $DEST $DEST_TARBALL failed, error: $status" 1>&2
	exit 6
    fi

    # cleanup temporary tree
    #
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: rm -rf $SUBMIT_UNPACK_DIR" 1>&2
    fi
    rm -rf "$SUBMIT_UNPACK_DIR"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: rm -rf $SUBMIT_UNPACK_DIR failed, error: $status" 1>&2
	exit 6
    fi
    trap - 0 1 2 3 15

    # perform chkentry test on the submission directory
    #
    export AUTH_JSON="$SUBMIT_DIR/.auth.json"
    if [[ ! -r $AUTH_JSON ]]; then
	echo "$0: ERROR: .auth.json readable file not found: $AUTH_JSON" 1>&2
	exit 9
    fi
    export INFO_JSON="$SUBMIT_DIR/.info.json"
    if [[ ! -r $INFO_JSON ]]; then
	echo "$0: ERROR: .info.json readable file not found: $INFO_JSON" 1>&2
	exit 9
    fi
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: $CHKENTRY_TOOL -q $AUTH_JSON $INFO_JSON" 1>&2
    fi
    "$CHKENTRY_TOOL" -q "$AUTH_JSON" "$INFO_JSON"
    status="$?"
    if [[ $status -ne 0 ]]; then

	# report chkentry failure
	#
	echo "$0: ERROR: $CHKENTRY_TOOL -q $AUTH_JSON $INFO_JSON failed, error: $status" 1>&2

	# update the slot comment with the txzchk failure
	#
	COMMENT="submit file failed chkentry test!  Use mkiocccentry to rebuild and resubmit to this slot."
	if [[ $V_FLAG -ge 1 ]]; then
	    echo "$0: debug[1]: about to: $SSH_TOOL -n -p $REMOTE_PORT $REMOTE_USER@$SERVER $RMT_SET_SLOT_STATUS_PY $USERNAME $SLOT_NUM '$COMMENT' > /dev/null" 1>&2
	fi
	"$SSH_TOOL" -n -p "$REMOTE_PORT" "$REMOTE_USER@$SERVER" "$RMT_SET_SLOT_STATUS_PY" "$USERNAME" "$SLOT_NUM" "'$COMMENT'" >/dev/null
	status="$?"
	if [[ $status -ne 0 ]]; then
	    echo "$0: ERROR: $SSH_TOOL -n -p $REMOTE_PORT $REMOTE_USER@$SERVER $RMT_SET_SLOT_STATUS_PY $USERNAME $SLOT_NUM '$COMMENT' > /dev/null failed, error: $status" 1>&2
	    exit 6
	fi

	# move destination file into errors
	#
	if [[ $V_FLAG -ge 1 ]]; then
	    echo "$0: debug[1]: about to: mv -v -f $DEST $ERRORS" 1>&2
	fi
	mv -v -f "$DEST" "$ERRORS"
	status="$?"
	if [[ $status -ne 0 ]]; then
	    echo "$0: ERROR: mv -v -f $DEST $ERRORS failed, error: $status" 1>&2
	    exit 6
	fi

	# exit non-zero due to txzchk failure
	#
	exit 9
    fi

    # as an "gram of protection", compress the .auth.json file
    #
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: $XZ_TOOL -z -f $AUTH_JSON" 1>&2
    fi
    "$XZ_TOOL" -z -f "$AUTH_JSON"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: $XZ_TOOL -z -f $AUTH_JSON failed, error: $status" 1>&2
	exit 6
    fi

    # report submission success
    #
    COMMENT="submit file received by IOCCC judges and passed both txzchk and chkentry tests"
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: $SSH_TOOL -n -p $REMOTE_PORT $REMOTE_USER@$SERVER $RMT_SET_SLOT_STATUS_PY $USERNAME $SLOT_NUM '$COMMENT' > /dev/null" 1>&2
    fi
    "$SSH_TOOL" -n -p "$REMOTE_PORT" "$REMOTE_USER@$SERVER" "$RMT_SET_SLOT_STATUS_PY" "$USERNAME" "$SLOT_NUM" "'$COMMENT'" >/dev/null
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: $SSH_TOOL -n -p $REMOTE_PORT $REMOTE_USER@$SERVER $RMT_SET_SLOT_STATUS_PY $USERNAME $SLOT_NUM '$COMMENT' > /dev/null failed, error: $status" 1>&2
	exit 6
    fi
fi


# case: we have 1 or more unexpected files
#
# Use rsync to "move" and files found in the remote server unexpected directory
# to under the local errors directory.  By "move" we mean that we remove files
# under the remote server unexpected directory after they are copied into
# the local errors directory.
#
if [[ -z $NOOP && $UNEXPECTED_COUNT -ge 1 ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: $RSYNC_TOOL -z -e \"$SSH_TOOL -a -T -p $REMOTE_PORT -q -x -o Compression=no -o ConnectionAttempts=20\" -a -S -0 --no-motd --remove-source-files $REMOTE_USER@$SERVER:$REMOTE_TOPDIR/unexpected/ $ERRORS" 1>&2
    fi
    "$RSYNC_TOOL" -z -e "$SSH_TOOL -a -T -p $REMOTE_PORT -q -x -o Compression=no -o ConnectionAttempts=20" -a -S -0 --no-motd --remove-source-files "$REMOTE_USER@$SERVER:$REMOTE_TOPDIR/unexpected/" "$ERRORS"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: $RSYNC_TOOL -z -e \"$SSH_TOOL -a -T -p $REMOTE_PORT -q -x -o Compression=no -o ConnectionAttempts=20\" -a -S -0 --no-motd --remove-source-files $REMOTE_USER@$SERVER:$REMOTE_TOPDIR/unexpected/ $ERRORS failed, error: $status" 1>&2
	exit 8
    fi
fi


# All Done!!! All Done!!! -- Jessica Noll, Age 2
#
exit 0
