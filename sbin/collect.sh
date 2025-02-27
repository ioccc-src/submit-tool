#!/usr/bin/env bash
#
# collect.sh - remotely stage a submit file and collect it
#
# For a given slot directory path on the remote IOCCC submit server, we
# collect the submit file into a local directory, perform tests and un-tar it,
# and update the status of the slot on remote IOCCC submit server accordingly.
# The file changes under the local workdir are checked into git.
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
export VERSION="2.4.2 2025-02-26"
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
export USER_NAME
if [[ -z $USER_NAME ]]; then
    USER_NAME=$(id -u -n)
fi
#
export RMT_USER
if [[ -z $RMT_USER ]]; then
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
export RMT_STAGE_PY
if [[ -z $RMT_STAGE_PY ]]; then
    RMT_STAGE_PY="/usr/ioccc/bin/stage.py"
fi
#
export RMT_SET_SLOT_STATUS_PY
if [[ -z $RMT_SET_SLOT_STATUS_PY ]]; then
    RMT_SET_SLOT_STATUS_PY="/usr/ioccc/bin/set_slot_status.py"
fi
#
export SSH_TOOL
if [[ -z $SSH_TOOL ]]; then
    SSH_TOOL=$(type -P ssh)
    if [[ -z "$SSH_TOOL" ]]; then
	echo "$0: FATAL: ssh tool is not installed or not in \$PATH" 1>&2
	exit 5
    fi
fi
#
export RMT_RUN_SH
if [[ -z $RMT_RUN_SH ]]; then
    RMT_RUN_SH="/usr/ioccc/bin/run.sh"
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
export SHA256_TOOL
if [[ -z $SHA256_TOOL ]]; then
    SHA256_TOOL=$(type -P sha256sum)
    if [[ -z "$SHA256_TOOL" ]]; then
	echo "$0: FATAL: sha256sum tool is not installed or not in \$PATH" 1>&2
	exit 5
    fi
fi
#
export RSYNC_TOOL
if [[ -z $RSYNC_TOOL ]]; then
    RSYNC_TOOL=$(type -P rsync)
    if [[ -z "$RSYNC_TOOL" ]]; then
	echo "$0: FATAL: rsync tool is not installed or not in \$PATH" 1>&2
	exit 5
    fi
fi
#
export TXZCHK_TOOL
if [[ -z $TXZCHK_TOOL ]]; then
    TXZCHK_TOOL=$(type -P txzchk)
    if [[ -z "$TXZCHK_TOOL" ]]; then
	echo "$0: FATAL: txzchk tool is not installed or not in \$PATH" 1>&2
	exit 5
    fi
fi
#
export CHKENTRY_TOOL
if [[ -z $CHKENTRY_TOOL ]]; then
    CHKENTRY_TOOL=$(type -P chkentry)
    if [[ -z "$CHKENTRY_TOOL" ]]; then
	echo "$0: FATAL: chkentry tool is not installed or not in \$PATH" 1>&2
	exit 5
    fi
fi
#
export XZ_TOOL
if [[ -z $XZ_TOOL ]]; then
    XZ_TOOL=$(type -P xz)
    if [[ -z "$XZ_TOOL" ]]; then
	echo "$0: FATAL: xz tool is not installed or not in \$PATH" 1>&2
	exit 5
    fi
fi
#
export GIT_TOOL
if [[ -z $GIT_TOOL ]]; then
    GIT_TOOL=$(type -P git)
    if [[ -z "$GIT_TOOL" ]]; then
	echo "$0: FATAL: git tool is not installed or not in \$PATH" 1>&2
	exit 5
    fi
fi
#
export USE_GIT="true"
export WORKDIR="/usr/ioccc/ioccc-work"


# add_git - If we are using git, add file to git
#
# usage:
#   add_git file
#
#   file - file to add to git
#
# returns:
#     0 ==> no errors detected
#   > 0 ==> function error number
#
# NOTE: This function does nothing if we are not using git.
#
function add_git
{
    local FILE  # file to add to git

    # firewall - must be using git
    #
    if [[ -z $USE_GIT ]]; then
	# not using git, nothing to do
	return 0
    fi

    # parse args
    #
    if [[ $# -ne 1 ]]; then
        echo "$0: Warning: in add_git: expected 1 arg, found $#" 1>&2
        return 1
    fi
    FILE="$1"

    # firewall - file must exist
    #
    if [[ ! -e $FILE ]]; then
        echo "$0: Warning: in add_git: does not exist: $MSG_FILE" 1>&2
        return 2
    fi

    # git add
    #
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: in add_git: about to: $GIT_TOOL add $FILE" 1>&2
    fi
    "$GIT_TOOL" add "$FILE"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: Warning: in add_git: $GIT_TOOL add $FILE failed, error: $status" 1>&2
	return 3
    fi

    # all OK
    #
    return 0
}


# commit_git - If we are using git, commit changes with a commit message
#
# usage:
#   commit_git msg_file
#
#   msg_file - file containing the text for the commit message
#
# returns:
#     0 ==> no errors detected
#   > 0 ==> function error number
#
# NOTE: This function does nothing if we are not using git.
#
function commit_git
{
    local MSG_FILE  # file containing the text for the commit message

    # firewall - must be using git
    #
    if [[ -z $USE_GIT ]]; then
	# not using git, nothing to do
	return 0
    fi

    # parse args
    #
    if [[ $# -ne 1 ]]; then
        echo "$0: Warning: in commit_git: expected 1 arg, found $#" 1>&2
        return 1
    fi
    MSG_FILE="$1"

    # firewall - file containing the text for the commit message must not be empty
    #
    if [[ ! -s $MSG_FILE ]]; then
        echo "$0: Warning: in commit_git: MSG_FILE is not a non-empty file: $MSG_FILE" 1>&2
        return 2
    fi

    # git commit
    #
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: in commit_git: about to: $GIT_TOOL commit --allow-empty -q -F $MSG_FILE" 1>&2
    fi
    "$GIT_TOOL" commit --allow-empty -q -F "$MSG_FILE"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: Warning: in commit_git: $GIT_TOOL commit --allow-empty -q -F $MSG_FILE failed, error: $status" 1>&2
	return 3
    fi

    # all OK
    #
    return 0
}


# push_git - If we are using git, push commit(s) to repo
#
# usage:
#   push_git .
#
#   NOTE: The argument to this function is ignored.
#	  We have an argument to silence shellcheck warning 2120 and note 2119.
#
# returns:
#     0 ==> no errors detected
#   > 0 ==> function error number
#
# NOTE: This function does nothing if we are not using git.
#
function push_git
{
    local IGNORED   # ignored argument

    # firewall - must be using git
    #
    if [[ -z $USE_GIT ]]; then
	# not using git, nothing to do
	return 0
    fi

    # parse args
    #
    if [[ $# -ne 1 ]]; then
        echo "$0: Warning: in push_git: expected 1 arg, found $#" 1>&2
        return 1
    fi
    IGNORED="$1"

    # git push
    #
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: in push_git: about to: $GIT_TOOL push 2>/dev/null" 1>&2
    fi
    if [[ $V_FLAG -ge 5 ]]; then
	# This debug message is to silence shellcheck warning 2034
	echo "$0: debug[5]: in push_git: ignored arg is: $IGNORED" 1>&2
    fi
    "$GIT_TOOL" push 2>/dev/null
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: Warning: in push_git: $GIT_TOOL push 2>/dev/null  failed, error: $status" 1>&2
	return 2
    fi

    # all OK
    #
    return 0
}


# mv_to_errors - move something under the ERRORS directory
#
# usage:
#   mv_to_errors file
#
#   file - file to move under ERRORS
#
# returns:
#     0 ==> no errors detected
#   > 0 ==> function error number
#
function mv_to_errors
{
    local FILE  # file to add to git

    # parse args
    #
    if [[ $# -ne 1 ]]; then
        echo "$0: Warning: in mv_to_errors: expected 1 arg, found $#" 1>&2
        return 1
    fi
    FILE="$1"

    # firewall - file must exist
    #
    if [[ ! -e $FILE ]]; then
        echo "$0: Warning: in mv_to_errors: does not exist: $FILE" 1>&2
        return 2
    fi

    # firewall - ERRORS must be a writable directory
    #
    if [[ ! -d $ERRORS ]]; then
        echo "$0: Warning: in mv_to_errors: not a directory: $ERRORS" 1>&2
        return 3
    fi
    if [[ ! -w $ERRORS ]]; then
        echo "$0: Warning: in mv_to_errors: not a writable directory: $ERRORS" 1>&2
        return 4
    fi

    # move destination file into errors
    #
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: in mv_to_errors: about to: mv -f $FILE $ERRORS" 1>&2
    fi
    mv -f "$FILE" "$ERRORS"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: Warning: in mv_to_errors: mv -f $FILE $ERRORS failed, error: $status" 1>&2
	return 5
    fi

    # all OK
    #
    return 0
}


# change_slot_comment - change to status comment of a slot
#
# usage:
#   change_slot_comment username slot_num comment
#
#   ioccc_user	- remote server IOCCC username
#   slot	- slot number to change
#   comment	- new status comment of a slot
#
# returns:
#     0 ==> no errors detected
#   > 0 ==> function error number
#
# NOTE: The slot collected state will also be set to True.
#
function change_slot_comment
{
    local IOCCC_USER	# remote server IOCCC username
    local SLOT		# slot number to change
    local COMMENT	# new status comment of a slot

    # parse args
    #
    if [[ $# -ne 3 ]]; then
        echo "$0: Warning: in change_slot_comment: expected 3 args, found $#" 1>&2
        return 1
    fi
    IOCCC_USER="$1"
    SLOT="$2"
    COMMENT="$3"

    # ssh to remove server to run RMT_SET_SLOT_STATUS_PY to set slot comment and set collected to True
    #
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: in change_slot_comment: about to: $SSH_TOOL -n -p $RMT_PORT $RMT_USER@$SERVER $RMT_RUN_SH $RMT_SET_SLOT_STATUS_PY -c $IOCCC_USER $SLOT '$COMMENT' >/dev/null 2>&1" 1>&2
    fi
    "$SSH_TOOL" -n -p "$RMT_PORT" "$RMT_USER@$SERVER" "$RMT_RUN_SH" "$RMT_SET_SLOT_STATUS_PY" -c "$IOCCC_USER" "$SLOT" "'$COMMENT'" >/dev/null 2>&1
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: Warning: in change_slot_comment: $SSH_TOOL -n -p $RMT_PORT $RMT_USER@$SERVER $RMT_RUN_SH $RMT_SET_SLOT_STATUS_PY -c $IOCCC_USER $SLOT '$COMMENT' >/dev/null 2>&1 failed, error: $status" 1>&2
	return 2
    fi

    # all OK
    #
    return 0
}


# unexpected_collect - collect unexpected files under ERRORS
#
# We do nothing if the count is <= 0.
#
# Use rsync to "move" and files found in the remote server unexpected directory
# to under the local errors directory.  By "move" we mean that we remove files
# under the remote server unexpected directory after they are copied into
# the local ERRORS directory.
#
# usage:
#   unexpected_collect count
#
#   count - number of unexpected files
#
# returns:
#     0 ==> no errors detected
#   > 0 ==> function error number
#
function unexpected_collect
{
    local COUNT  # file to add to git

    # parse args
    #
    if [[ $# -ne 1 ]]; then
        echo "$0: Warning: in unexpected_collect: expected 1 arg, found $#" 1>&2
        return 1
    fi
    COUNT="$1"

    # firewall - we can only do something when COUNT > 0
    #
    if [[ $COUNT -lt 1 ]]; then
	return 0
    fi

    # firewall - ERRORS must be a writable directory
    #
    if [[ ! -d $ERRORS ]]; then
        echo "$0: Warning: in unexpected_collect: not a directory: $ERRORS" 1>&2
        return 2
    fi
    if [[ ! -w $ERRORS ]]; then
        echo "$0: Warning: in unexpected_collect: not a writable directory: $ERRORS" 1>&2
        return 3
    fi

    # collect all remote files under unexpected
    #
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: in unexpected_collect: about to: $RSYNC_TOOL -z -e \"$SSH_TOOL -a -T -p $RMT_PORT -q -x -o Compression=no -o ConnectionAttempts=20\" -a -S -0 --no-motd --remove-source-files $USER_NAME@$SERVER:$RMT_TOPDIR/unexpected/ $ERRORS" 1>&2
    fi
    if [[ -n $USE_GIT ]]; then
	{
	    echo
	    echo "Fetching $UNEXPECTED_COUNT unexpected file(s) from $USER_NAME@$SERVER:$RMT_TOPDIR/unexpected/"
	    echo "Output from $RSYNC_TOOL follows:"
	    echo
	} | if [[ -n $USE_GIT ]]; then
	    cat >> "$TMP_GIT_COMMIT"
	    "$RSYNC_TOOL" -z -e "$SSH_TOOL -a -T -p $RMT_PORT -q -x -o Compression=no -o ConnectionAttempts=20" -a -S -0 --no-motd --remove-source-files -v "$USER_NAME@$SERVER:$RMT_TOPDIR/unexpected/" "$ERRORS" >> "$TMP_GIT_COMMIT" 2>&1
	else
	    cat 1>&2
	    "$RSYNC_TOOL" -z -e "$SSH_TOOL -a -T -p $RMT_PORT -q -x -o Compression=no -o ConnectionAttempts=20" -a -S -0 --no-motd --remove-source-files "$USER_NAME@$SERVER:$RMT_TOPDIR/unexpected/" "$ERRORS"
	fi
    fi

    # all OK
    #
    return 0
}


# usage
#
export USAGE="usage: $0 [-h] [-v level] [-V] [-n] [-N] [-t rmt_topdir] [-i ioccc.rc] [-I]
	[-p rmt_port] [-u rmt_user] [-H rmt_host]
	[-s ssh_tool] [-r rmt_run] [-c scp_tool] [-s sha256_tool] [-R rsync_root] [-x xz] [-g git_tool] [-G]
	[-z txzchk] [-y chkenry] [-S rmt_stage] [-C slot_comment] [-w workdir]
	rmt_slot_path

	-h		print help message and exit
	-v level	set verbosity level (def level: 0)
	-V		print version string and exit

	-n		go thru the actions, but do not update any files (def: do the action)
	-N		do not process anything, just parse arguments (def: process something)

	-t rmt_topdir   app directory path on server (def: $RMT_TOPDIR)

	-i ioccc.rc	Use ioccc.rc as the rc startup file (def: $IOCCC_RC)
	-I		Do not use any rc startup file (def: do)

	-p rmt_port	use ssh TCP port (def: $RMT_PORT)
	-u rmt_user	ssh into this user (def: $RMT_USER)
	-H rmt_host	ssh host to use (def: $SERVER)

	-s ssh_tool	use local ssh_tool to ssh (def: $SSH_TOOL)
	-r rmt_run	path to run.sh on the remote server (def: $RMT_RUN_SH)
	-c scp_tool	use local scp_tool to scp (def: $SCP_TOOL)
	-2 sha256_tool	use local sha256_tool to hash (def: $SHA256_TOOL)
	-R rsync_root	use local rsync tool to sync trees (def: $RSYNC_TOOL)
	-x xz		use local xz tool to compress (def: $XZ_TOOL)
	-g git_tool	use local git tool to manage files (def: $GIT_TOOL)

	-G		disable git operations (def: try to use git)

	-z txzchk	use local txzchk tool to test compressed tarballs (def: $TXZCHK_TOOL)
	-y chkenry	use local chkenry tool to test unpacked submission (def: $CHKENTRY_TOOL)

	-S rmt_stage	path to stage.py on the remote server (def: $RMT_STAGE_PY)
	-C slot_comment	path to set_slot_status.py on the remote server (def: $RMT_SET_SLOT_STATUS_PY)

	-w workdir	cd to the workdir before running (def: stay in $WORKDIR)

	rmt_slot_path	The path on the remote side, of the slot to process

	NOTE: The slot_path can be relative to the rmt_topdir

Exit codes:
     0        all OK
     1        some internal tool is missing or exited non-zero
     2        -h and help string printed or -V and version string printed
     3        command line error
     4        source of ioccc.rc file failed
     5        some critical local executable tool not found
     6        remote execution of a tool failed, returned an exit code, or returned a malformed response
     7        inbound and/or error are not writable directories, or workdir is not a directory
     8        scp of remote file(s) or ssh rm -f of file(s) failed
     9        downloaded file failed local tests
 >= 10        internal error

$NAME version: $VERSION"


# parse command line
#
while getopts :hv:VnNt:i:Ip:u:H:s:r:c:2:R:x:g:Gz:y:S:C:w: flag; do
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
    s) SSH_TOOL="$OPTARG"
	;;
    r) RMT_RUN_SH="$OPTARG"
	;;
    c) SCP_TOOL="$OPTARG"
	;;
    2) SHA256_TOOL="$OPTARG"
	;;
    R) RSYNC_TOOL="$OPTARG"
	;;
    x) XZ_TOOL="$OPTARG"
	;;
    g) GIT_TOOL="$OPTARG"
	;;
    G) USE_GIT=
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
IOCCC_USERNAME=$(basename "$RMT_SLOT_DIRNAME")
export IOCCC_USERNAME


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
    echo "$0: debug[3]: RMT_TOPDIR=$RMT_TOPDIR" 1>&2
    echo "$0: debug[3]: IOCCC_RC=$IOCCC_RC" 1>&2
    echo "$0: debug[3]: CAP_I_FLAG=$CAP_I_FLAG" 1>&2
    echo "$0: debug[3]: RMT_PORT=$RMT_PORT" 1>&2
    echo "$0: debug[3]: USER_NAME=$USER_NAME" 1>&2
    echo "$0: debug[3]: RMT_USER=$RMT_USER" 1>&2
    echo "$0: debug[3]: SERVER=$SERVER" 1>&2
    echo "$0: debug[3]: SSH_TOOL=$SSH_TOOL" 1>&2
    echo "$0: debug[3]: RMT_RUN_SH=$RMT_RUN_SH" 1>&2
    echo "$0: debug[3]: SCP_TOOL=$SCP_TOOL" 1>&2
    echo "$0: debug[3]: SHA256_TOOL=$SHA256_TOOL" 1>&2
    echo "$0: debug[3]: RSYNC_TOOL=$RSYNC_TOOL" 1>&2
    echo "$0: debug[3]: XZ_TOOL=$XZ_TOOL" 1>&2
    echo "$0: debug[3]: TXZCHK_TOOL=$TXZCHK_TOOL" 1>&2
    echo "$0: debug[3]: CHKENTRY_TOOL=$CHKENTRY_TOOL" 1>&2
    echo "$0: debug[3]: GIT_TOOL=$GIT_TOOL" 1>&2
    echo "$0: debug[3]: USE_GIT=$USE_GIT" 1>&2
    echo "$0: debug[3]: RMT_STAGE_PY=$RMT_STAGE_PY" 1>&2
    echo "$0: debug[3]: RMT_SET_SLOT_STATUS_PY=$RMT_SET_SLOT_STATUS_PY" 1>&2
    echo "$0: debug[3]: WORKDIR=$WORKDIR" 1>&2
    echo "$0: debug[3]: RMT_SLOT_PATH=$RMT_SLOT_PATH" 1>&2
    echo "$0: debug[3]: SLOT_NUM=$SLOT_NUM" 1>&2
    echo "$0: debug[3]: IOCCC_USERNAME=$IOCCC_USERNAME" 1>&2
fi


# determine if we can use git
#
# Use of -G will always prevent use of git.
#
# We will perform several tests to determine (unless -G was used),
# if the use of git is possible and wise.
#
if [[ -n $USE_GIT ]]; then

    # WORKDIR must be under git control to use git
    #
    if "$GIT_TOOL" -C "$WORKDIR" rev-parse 2>/dev/null; then

	# While WORKDIR is under git control,
	# we do NOT want to use git under common IOCCC related repos
	# that certain well known files or directories.
	#
	for i in jparse.c mkiocccentry.c F iocccsubmit 1984; do
	    if [[ -e $WORKDIR/$i ]]; then
		if [[ $V_FLAG -ge 3 ]]; then
		    echo "$0: debug[3]: found $WORKDIR/$i, disabling use of git" 1>&2
		fi
		USE_GIT=
		break
	    fi
	done

    else
	if [[ $V_FLAG -ge 3 ]]; then
	    echo "$0: debug[3]: $GIT_TOOL -C $WORKDIR rev-parse 2>/dev/null is false, disabling use of git" 1>&2
	fi
	USE_GIT=
    fi

    # Must have a non-empty DO.NOT.DISTRIBUTE readable file
    #
    if [[ ! -e $WORKDIR/DO.NOT.DISTRIBUTE ]]; then
	if [[ $V_FLAG -ge 3 ]]; then
	    echo "$0: debug[3]: $WORKDIR/DO.NOT.DISTRIBUTE does not exist, disabling use of git" 1>&2
	fi
	USE_GIT=
    elif [[ ! -f $WORKDIR/DO.NOT.DISTRIBUTE ]]; then
	if [[ $V_FLAG -ge 3 ]]; then
	    echo "$0: debug[3]: $WORKDIR/DO.NOT.DISTRIBUTE is not a file, disabling use of git" 1>&2
	fi
	USE_GIT=
    elif [[ ! -r $WORKDIR/DO.NOT.DISTRIBUTE ]]; then
	if [[ $V_FLAG -ge 3 ]]; then
	    echo "$0: debug[3]: $WORKDIR/DO.NOT.DISTRIBUTE is not a readable file, disabling use of git" 1>&2
	fi
	USE_GIT=
    elif [[ ! -r $WORKDIR/DO.NOT.DISTRIBUTE ]]; then
	if [[ $V_FLAG -ge 3 ]]; then
	    echo "$0: debug[3]: $WORKDIR/DO.NOT.DISTRIBUTE is not a non-empty readable file, disabling use of git" 1>&2
	fi
	USE_GIT=
    fi

# case: -G used
#
else
    if [[ $V_FLAG -ge 3 ]]; then
	echo "$0: debug[3]: use of -G, disabling use of git" 1>&2
    fi
fi
if [[ $V_FLAG -ge 1 ]]; then
    if [[ -z $USE_GIT ]]; then
	echo "$0: debug[1]: use of git is disabled" 1>&2
    else
	echo "$0: debug[1]: enabled use of git" 1>&2
    fi
fi


# firewall - GIT_TOOL must be executable if git is to be used
#
if [[ -n $USE_GIT ]]; then
    if [[ ! -x $GIT_TOOL ]]; then
	echo "$0: ERROR: git tool not executable: $GIT_TOOL" 1>&2
	exit 5
    fi
fi


# form temporary git commit message if git is to be used
#
export TMP_GIT_COMMIT="$WORKDIR/.tmp.$NAME.GIT_COMMIT.$$.tmp"
if [[ -z $NOOP ]]; then
    if [[ -n $USE_GIT ]]; then
	if [[ $V_FLAG -ge 3 ]]; then
	    echo  "$0: debug[3]: temporary git commit message file: $TMP_GIT_COMMIT" 1>&2
	fi
	trap 'rm -f $TMP_GIT_COMMIT; exit' 0 1 2 3 15
	rm -f "$TMP_GIT_COMMIT"
	if [[ -e $TMP_GIT_COMMIT ]]; then
	    echo "$0: ERROR: cannot remove git commit message file: $TMP_GIT_COMMIT" 1>&2
	    exit 10
	fi
	: >  "$TMP_GIT_COMMIT"
	if [[ ! -e $TMP_GIT_COMMIT ]]; then
	    echo "$0: ERROR: cannot create git commit message file: $TMP_GIT_COMMIT" 1>&2
	    exit 11
	fi
    fi
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not form git commit message: $TMP_GIT_COMMIT" 1>&2
fi


# form temporary stderr collection file
#
export TMP_STDERR="$WORKDIR/.tmp.$NAME.STDERR.$$.tmp"
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 3 ]]; then
	echo  "$0: debug[3]: temporary stderr collection file: $TMP_STDERR" 1>&2
    fi
    trap 'rm -f $TMP_GIT_COMMIT $TMP_STDERR; exit' 0 1 2 3 15
    rm -f "$TMP_STDERR"
    if [[ -e $TMP_STDERR ]]; then
	echo "$0: ERROR: cannot remove stderr collection file: $TMP_STDERR" 1>&2
	exit 12
    fi
    : >  "$TMP_STDERR"
    if [[ ! -e $TMP_STDERR ]]; then
	echo "$0: ERROR: cannot create stderr collection file: $TMP_STDERR" 1>&2
	exit 13
    fi
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not form temporary stderr collection file: $TMP_STDERR" 1>&2
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
if [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: current working directory is: $(/bin/pwd)" 1>&2
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


# -n also stops early before any processing is performed because adding NOOP to individual code is too complex
#
if [[ -n $NOOP ]]; then
    if [[ $V_FLAG -ge 3 ]]; then
	echo "$0: debug[3]: arguments parsed, -n given, exiting 0" 1>&2
    fi
    exit 0
fi


# start with "no problem" problem code
#
export PROBLEM_CODE=0


# if using git, initialize git commit message
#
if [[ -n $USE_GIT ]]; then
    {
	echo "process $RMT_SLOT_PATH"
	echo
	echo "This run on $(date -u) was produced by $NAME"
    } >> "$TMP_GIT_COMMIT"
fi


# run the remote stage.py tool via ssh, on the remote server, and collect the reply
#
if [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: about to: $SSH_TOOL -n -p $RMT_PORT $RMT_USER@$SERVER $RMT_RUN_SH $RMT_STAGE_PY $RMT_SLOT_PATH 2>$TMP_STDERR" 1>&2
fi
ANSWER=$("$SSH_TOOL" -n -p "$RMT_PORT" "$RMT_USER@$SERVER" "$RMT_RUN_SH" "$RMT_STAGE_PY" "$RMT_SLOT_PATH" 2>"$TMP_STDERR")
status="$?"
if [[ -z $ANSWER ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: $RMT_STAGE_PY $RMT_SLOT_PATH answer was empty" 1>&2
    fi
    # we have no response from RMT_STAGE_PY - we can do thing more at this stage
    exit 0
fi
if [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: stage.py returned: $ANSWER" 1>&2
fi
if [[ $status -ne 0 ]]; then

    # record RMT_SLOT_PATH non-zero exit
    #
    PROBLEM_CODE=1
    if [[ $status -ne 0 ]]; then
	{
	    echo
	    echo "$0: Warning: $SSH_TOOL -n -p $RMT_PORT $RMT_USER@$SERVER $RMT_RUN_SH $RMT_STAGE_PY $RMT_SLOT_PATH 2>$TMP_STDERR failed, error: $status"
	    echo "$0: Warning: stderr output starts below"
	    cat "$TMP_STDERR"
	    echo "$0: Warning: stderr output ends above"
	    echo "$0: Warning: Set PROBLEM_CODE: $PROBLEM_CODE"
	} | if [[ -n $USE_GIT ]]; then
	    cat >> "$TMP_GIT_COMMIT"
	else
	    cat 1>&2
	fi
    fi
fi
if [[ -n $USE_GIT ]]; then
    {
	echo
	echo "$SSH_TOOL -n -p $RMT_PORT $RMT_USER@$SERVER $RMT_RUN_SH $RMT_STAGE_PY $RMT_SLOT_PATH returned:"
	echo
	echo "$ANSWER"
    } >> "$TMP_GIT_COMMIT"
fi


# parse answer from remote stage.py tool
#
read -r HEXDIGEST STAGED_PATH UNEXPECTED_COUNT EXTRA <<< "$ANSWER"
if [[ -z $HEXDIGEST ]]; then
    HEXDIGEST="None"
    PROBLEM_CODE=2
    if [[ $status -ne 0 ]]; then
	{
	    echo
	    echo "$0: Warning: HEXDIGEST was empty, reset to: $HEXDIGEST"
	    echo "$0: Warning: Set PROBLEM_CODE: $PROBLEM_CODE"
	} | if [[ -n $USE_GIT ]]; then
	    cat >> "$TMP_GIT_COMMIT"
	else
	    cat 1>&2
	fi
    fi
fi
if [[ -z $STAGED_PATH ]]; then
    STAGED_PATH="."
    PROBLEM_CODE=3
    if [[ $status -ne 0 ]]; then
	{
	    echo
	    echo "$0: Warning: STAGED_PATH was empty, reset to: $STAGED_PATH"
	    echo "$0: Warning: Set PROBLEM_CODE: $PROBLEM_CODE"
	} | if [[ -n $USE_GIT ]]; then
	    cat >> "$TMP_GIT_COMMIT"
	else
	    cat 1>&2
	fi
    fi
fi
if [[ -z $UNEXPECTED_COUNT ]]; then
    UNEXPECTED_COUNT=0
    PROBLEM_CODE=4
    if [[ $status -ne 0 ]]; then
	{
	    echo
	    echo "$0: Warning: UNEXPECTED_COUNT was empty, reset to: $UNEXPECTED_COUNT"
	    echo "$0: Warning: Set PROBLEM_CODE: $PROBLEM_CODE"
	} | if [[ -n $USE_GIT ]]; then
	    cat >> "$TMP_GIT_COMMIT"
	else
	    cat 1>&2
	fi
    fi
fi
if [[ -n $EXTRA ]]; then
    PROBLEM_CODE=5
    if [[ $status -ne 0 ]]; then
	{
	    echo
	    echo "$0: Warning: received 4 or more fields, expected only 3"
	    echo "$0: Warning: Set PROBLEM_CODE: $PROBLEM_CODE"
	} | if [[ -n $USE_GIT ]]; then
	    cat >> "$TMP_GIT_COMMIT"
	else
	    cat 1>&2
	fi
    fi
fi
if [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: HEXDIGEST=$HEXDIGEST" 1>&2
    echo "$0: debug[3]: STAGED_PATH=$STAGED_PATH" 1>&2
    echo "$0: debug[3]: UNEXPECTED_COUNT=$UNEXPECTED_COUNT" 1>&2
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
    PROBLEM_CODE=6
    if [[ -z $EXIT_CODE ]]; then
	{
	    echo
	    echo "$0: Warning: HEXDIGEST stats with exit. but lacks code: $HEXDIGEST"
	    echo "$0: Warning: Set PROBLEM_CODE: $PROBLEM_CODE"
	} | if [[ -n $USE_GIT ]]; then
	    cat >> "$TMP_GIT_COMMIT"
	else
	    cat 1>&2
	fi
    fi
fi


# firewall - now that the exit.code has been taken care of, verify HEXDIGEST is a SHA256 hex digest
#
if ! [[ $HEXDIGEST =~ ^[0-9a-f]+$ || ${#HEXDIGEST} -ne 64 ]]; then
    PROBLEM_CODE=7
    {
	echo
	echo "$0: Warning: HEXDIGEST is neither exit.code not SHA256 hash: $HEXDIGEST"
	echo "$0: Warning: Set PROBLEM_CODE: $PROBLEM_CODE"
    } | if [[ -n $USE_GIT ]]; then
	cat >> "$TMP_GIT_COMMIT"
    else
	cat 1>&2
    fi
fi


# firewall - STAGED_PATH cannot be . nor can PROBLEM_CODE be non-zero at this point
#
# When the remote stage.py tool ran into critical error that prevented it from moving the submit file
# under the staged directory, a STAGED_PATH of "." is returned.  Normally such a condition would have
# come with a HEXDIGEST of the form exit.code.  Just in case the HEXDIGEST is a SHA256 SHA256 hex digest,
# we deal with a "." STAGED_PATH here.
#
if [[ $STAGED_PATH == "." || $PROBLEM_CODE -ne 0 ]]; then

    # case: we have no staged file to process
    #
    if [[ $STAGED_PATH == "." ]]; then

	if [[ $PROBLEM_CODE -eq 0 ]]; then
	    # only set PROBLEM_CODE if it was not set above
	    PROBLEM_CODE=8
	fi
	{
	    echo
	    echo "$0: Warning: STAGED_PATH is ."
	    echo "$0: Warning: Set PROBLEM_CODE: $PROBLEM_CODE"
	} | if [[ -n $USE_GIT ]]; then
	    cat >> "$TMP_GIT_COMMIT"
	else
	    cat 1>&2
	fi
    fi

    # update the slot comment on the remote server to note the submit file corrupted on the server!
    #
    change_slot_comment "$IOCCC_USERNAME" "$SLOT_NUM" "server slot error code: $PROBLEM_CODE! Use mkiocccentry to rebuild and resubmit to this slot."

    # collect any unexpected files we may have received from RMT_SLOT_PATH under ERRORS
    #
    unexpected_collect "$UNEXPECTED_COUNT"

    # if using git, add ERRORS
    #
    add_git "$ERRORS"

    # if using git, commit the files that have been added
    #
    commit_git "$TMP_GIT_COMMIT"

    # if using git, push any commits
    #
    push_git .

    # exit non-zero due SHA256 hash mismatch - we can do thing more at this stage
    #
    exit 9
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
if [[ $STAGED_PATH == "." ]]; then
    echo "$0: ERROR: it should be impossible for STAGED_PATH to be . at this point, but it is for some reason" 1>&2
    exit 14
fi


# copy remote staged file into the inbound directory
#
if [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: about to: $SCP_TOOL -P $RMT_PORT $RMT_USER@$SERVER:$STAGED_PATH $DEST" 1>&2
fi
"$SCP_TOOL" -q -P "$RMT_PORT" "$RMT_USER@$SERVER:$STAGED_PATH" "$DEST"
status="$?"
if [[ $status -ne 0 ]]; then
    echo "$0: Warning: $SCP_TOOL -q -P $RMT_PORT $RMT_USER@$SERVER:$STAGED_PATH $DEST failed, error: $status" 1>&2
fi
if [[ ! -r $DEST ]]; then
    # We have no remote file - we can do thing more at this stage
    echo "$0: ERROR: destination file not found: $DEST" 1>&2
    exit 8
fi


# verify SHA256 hex digest
#
if [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: about to: $SHA256_TOOL $DEST" 1>&2
fi


# determine SHA256 hex digest hash of destination file
#
DEST_HEXDIGEST=$("$SHA256_TOOL" "$DEST")
status="$?"
if [[ $status -ne 0 ]]; then
    PROBLEM_CODE=10
    {
	echo
	echo "$0: Warning: $SHA256_TOOL $DEST failed, error: $status"
	echo "$0: Warning: Set PROBLEM_CODE: $PROBLEM_CODE"
    } | if [[ -n $USE_GIT ]]; then
	cat >> "$TMP_GIT_COMMIT"
    else
	cat 1>&2
    fi
fi
# remove filename from SHA256_TOOL output leaving just the SHA256 hex digest
DEST_HEXDIGEST=${DEST_HEXDIGEST%% *}
if [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: $SHA256_TOOL $DEST: $DEST_HEXDIGEST" 1>&2
fi


# case: SHA256 hex digest hash of destination file matches
#
if [[ $DEST_HEXDIGEST == "$HEXDIGEST" ]]; then

    # update the slot comment on the remote server to note the submit file was fetched
    #
    change_slot_comment "$IOCCC_USERNAME" "$SLOT_NUM" "submit file fetched by an IOCCC judge. The format test is pending."

# case: SHA256 hex digest hash of destination file is wrong
#
else
    PROBLEM_CODE=11
    {
	echo
	echo "$0: Warning: $DEST SHA256 hash: $DEST_HEXDIGEST != remote SHA256 hash: $HEXDIGEST"
	echo "$0: Warning: Set PROBLEM_CODE: $PROBLEM_CODE"
    } | if [[ -n $USE_GIT ]]; then
	cat >> "$TMP_GIT_COMMIT"
    else
	cat 1>&2
    fi

    # update the slot comment on the remote server to note the submit file corrupted on the server!
    #
    change_slot_comment "$IOCCC_USERNAME" "$SLOT_NUM" "submit file corrupted on the server! Use mkiocccentry to rebuild and resubmit to this slot."

    # move staged path file under ERRORS
    #
    mv_to_errors "$DEST"

    # collect any unexpected files we may have received from RMT_SLOT_PATH under ERRORS
    #
    unexpected_collect "$UNEXPECTED_COUNT"

    # if using git, add ERRORS
    #
    add_git "$ERRORS"

    # exit non-zero due SHA256 hash mismatch - we can do thing more at this stage
    #
    exit 9
fi


# remove the remote staged file, unless there was a problem
#
if [[ $PROBLEM_CODE -eq 0 ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: $SSH_TOOL -n -p $RMT_PORT $RMT_USER@$SERVER $RMT_RUN_SH rm -f $STAGED_PATH" 1>&2
    fi
    "$SSH_TOOL" -n -p "$RMT_PORT" "$RMT_USER@$SERVER" "$RMT_RUN_SH" rm -f "$STAGED_PATH"
    status="$?"
    if [[ $status -ne 0 ]]; then
	PROBLEM_CODE=12
	{
	    echo
	    echo "$0: Warning: $SSH_TOOL -n -p $RMT_PORT $RMT_USER@$SERVER $RMT_RUN_SH rm -f $STAGED_PATH failed, error: $status"
	    echo "$0: Warning: Set PROBLEM_CODE: $PROBLEM_CODE"
	} | if [[ -n $USE_GIT ]]; then
	    cat >> "$TMP_GIT_COMMIT"
	else
	    cat 1>&2
	fi
    fi
fi


# case: there was a problem, and we have a staged path file, move it into errors
#
if [[ $PROBLEM_CODE -ne 0 && -f $DEST ]]; then

    # move staged path file under ERRORS
    #
    mv_to_errors "$DEST"

    # if using git, add ERRORS
    #
    add_git "$ERRORS"

# case: no problem and a staged path file
#
elif [[ -f $DEST ]]; then

    # test the destination file using txzchk
    #
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: $TXZCHK_TOOL -q $DEST 2>$TMP_STDERR" 1>&2
    fi
    "$TXZCHK_TOOL" -q "$DEST" 2>"$TMP_STDERR"
    status="$?"
    if [[ $status -ne 0 ]]; then

	# report txzchk test failure
	#
	PROBLEM_CODE=13
	{
	    echo
	    echo "$0: Warning: $TXZCHK_TOOL -q $DEST 2>$TMP_STDERR failed, error: $status"
	    echo "$0: Warning: stderr output starts below"
	    cat "$TMP_STDERR"
	    echo "$0: Warning: stderr output ends above"
	    echo "$0: Warning: Set PROBLEM_CODE: $PROBLEM_CODE"
	} | if [[ -n $USE_GIT ]]; then
	    cat >> "$TMP_GIT_COMMIT"
	else
	    cat 1>&2
	fi

	# update the slot comment on the remote server to note txxchk test failure
	#
	change_slot_comment "$IOCCC_USERNAME" "$SLOT_NUM" "submit file failed the txxchk test! Use mkiocccentry to rebuild and resubmit to this slot."

	# move destination under ERRORS
	#
	mv_to_errors "$DEST"

	# collect any unexpected files we may have received from RMT_SLOT_PATH under ERRORS
	#
	unexpected_collect "$UNEXPECTED_COUNT"

	# if using git, add ERRORS
	#
	add_git "$ERRORS"

	# if using git, commit the files that have been added
	#
	commit_git "$TMP_GIT_COMMIT"

	# if using git, push any commits
	#
	push_git .

	# exit non-zero due to txzchk failure - we can do thing more at this stage
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
	# exit non-zero due to mkdir failure - we can do thing more at this stage
	exit 15
    fi

    # if we have a submission directory, create tarball holding directory
    #
    if [[ -d $SUBMIT_PARENT_DIR ]]; then

	export SUBMIT_TARBALL_DIR="$SUBMIT/$SUBMIT_USERSLOT/txz"
	if [[ $V_FLAG -ge 1 ]]; then
	    echo "$0: debug[1]: about to: mkdir -p $SUBMIT_TARBALL_DIR" 1>&2
	fi
	mkdir -p "$SUBMIT_TARBALL_DIR"
	status="$?"
	if [[ $status -ne 0 ]]; then
	    echo "$0: ERROR: mkdir -p $SUBMIT_TARBALL_DIR failed, error: $status" 1>&2
	    # exit non-zero due to mkdir failure - we can do thing more at this stage
	    exit 15
	fi

	# if we have a tarball holding directory, process it
	#
	if [[ -d $SUBMIT_TARBALL_DIR ]]; then

	    # create a new temporary unpack directory
	    #
	    export SUBMIT_UNPACK_DIR="$SUBMIT_PARENT_DIR/tmp.$$"
	    if [[ -n $USE_GIT ]]; then
		trap 'rm -rf $TMP_GIT_COMMIT $TMP_STDERR $SUBMIT_UNPACK_DIR; exit' 0 1 2 3 15
	    else
		trap 'rm -rf $SUBMIT_UNPACK_DIR $TMP_STDERR; exit' 0 1 2 3 15
	    fi
	    if [[ $V_FLAG -ge 1 ]]; then
		echo "$0: debug[1]: about to: mkdir -p $SUBMIT_UNPACK_DIR" 1>&2
	    fi
	    mkdir -p "$SUBMIT_UNPACK_DIR"
	    status="$?"
	    if [[ $status -ne 0 ]]; then
		echo "$0: ERROR: mkdir -p $SUBMIT_UNPACK_DIR failed, error: $status" 1>&2
		# exit non-zero due to mkdir failure - we can do thing more at this stage
		exit 16
	    fi

	    # if we have a temporary unpack directory, untar the submit file
	    #
	    if [[ -d $SUBMIT_UNPACK_DIR ]]; then

		# untar the submit file under the new temporary directory
		#
		if [[ $V_FLAG -ge 1 ]]; then
		    echo "$0: debug[1]: about to: tar -C $SUBMIT_UNPACK_DIR -Jxf $DEST 2>$TMP_STDERR"
		fi
		tar -C "$SUBMIT_UNPACK_DIR" -Jxf "$DEST" 2>"$TMP_STDERR"
		status="$?"
		if [[ $status -ne 0 ]]; then

		    # report untar failure
		    #
		    PROBLEM_CODE=14
		    {
			echo
			echo "$0: Warning: tar -C $SUBMIT_UNPACK_DIR -Jxf $DEST 2>$TMP_STDERR failed, error: $status"
			echo "$0: Warning: stderr output starts below"
			cat "$TMP_STDERR"
			echo "$0: Warning: stderr output ends above"
			echo "$0: Warning: Set PROBLEM_CODE: $PROBLEM_CODE"
		    } | if [[ -n $USE_GIT ]]; then
			cat >> "$TMP_GIT_COMMIT"
		    else
			cat 1>&2
		    fi

		    # update the slot comment on the remote server to note untar faulure
		    #
		    change_slot_comment "$IOCCC_USERNAME" "$SLOT_NUM" "submit file failed to untar! Use mkiocccentry to rebuild and resubmit to this slot."

		    # move destination under ERRORS
		    #
		    mv_to_errors "$DEST"

		    # collect any unexpected files we may have received from RMT_SLOT_PATH under ERRORS
		    #
		    unexpected_collect "$UNEXPECTED_COUNT"

		    # if using git, add ERRORS
		    #
		    add_git "$ERRORS"

		    # if using git, commit the files that have been added
		    #
		    commit_git "$TMP_GIT_COMMIT"

		    # if using git, push any commits
		    #
		    push_git .

		    # exit non-zero due to untar failure - we can do thing more at this stage
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
		    # exit non-zero due to mv failure - we can do thing more at this stage
		    exit 17
		fi

		# if we moved the temporary unpacked tree into place
		#
		if [[ -d $SUBMIT_DIR ]]; then

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
			# exit non-zero due to mv failure - we can do thing more at this stage
			exit 18
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
			# exit non-zero due to rm failure - we can do thing more at this stage
			exit 19
		    fi
		    if [[ -n $USE_GIT ]]; then
			trap 'rm -f $TMP_GIT_COMMIT $TMP_STDERR; exit' 0 1 2 3 15
		    else
			trap 'rm -f $TMP_STDERR' 0 1 2 3 15
		    fi

		    # perform chkentry test on the submission directory
		    #
		    if [[ $V_FLAG -ge 1 ]]; then
			echo "$0: debug[1]: about to: $CHKENTRY_TOOL -q $SUBMIT_DIR 2>$TMP_STDERR" 1>&2
		    fi
		    "$CHKENTRY_TOOL" -q "$SUBMIT_DIR" 2>"$TMP_STDERR"
		    status="$?"
		    if [[ $status -ne 0 ]]; then

			# report chkentry failure
			#
			PROBLEM_CODE=15
			{
			    echo
			    echo "$0: Warning: $CHKENTRY_TOOL -q $SUBMIT_DIR 2>$TMP_STDERR failed, error: $status"
			    echo "$0: Warning: stderr output starts below"
			    cat "$TMP_STDERR"
			    echo "$0: Warning: stderr output ends above"
			    echo "$0: Warning: Set PROBLEM_CODE: $PROBLEM_CODE"
			} | if [[ -n $USE_GIT ]]; then
			    cat >> "$TMP_GIT_COMMIT"
			else
			    cat 1>&2
			fi

			# update the slot comment on the remote server to note chkentry faulure
			#
			change_slot_comment "$IOCCC_USERNAME" "$SLOT_NUM" "submit file failed chkentry test! Use mkiocccentry to rebuild and resubmit to this slot."

			# move destination under ERRORS
			#
			mv_to_errors "$DEST"

			# collect any unexpected files we may have received from RMT_SLOT_PATH under ERRORS
			#
			unexpected_collect "$UNEXPECTED_COUNT"

			# if using git, add ERRORS
			#
			add_git "$ERRORS"

			# if using git, commit the files that have been added
			#
			commit_git "$TMP_GIT_COMMIT"

			# if using git, push any commits
			#
			push_git .

			# exit non-zero due to chkentry failure - we can do thing more at this stage
			#
			exit 9
		    fi

		    # as an "gram of protection", compress the .auth.json file
		    #
		    export AUTH_JSON="$SUBMIT_DIR/.auth.json"
		    if [[ $V_FLAG -ge 1 ]]; then
			echo "$0: debug[1]: about to: $XZ_TOOL -z -f $AUTH_JSON 2>$TMP_STDERR" 1>&2
		    fi
		    "$XZ_TOOL" -z -f "$AUTH_JSON" 2>"$TMP_STDERR"
		    status="$?"
		    if [[ $status -ne 0 ]]; then

			# report chkentry failure
			#
			PROBLEM_CODE=16
			{
			    echo
			    echo "$0: Warning: $XZ_TOOL -z -f $AUTH_JSON 2>$TMP_STDERR failed, error: $status"
			    echo "$0: Warning: stderr output starts below"
			    cat "$TMP_STDERR"
			    echo "$0: Warning: stderr output ends above"
			    echo "$0: Warning: Set PROBLEM_CODE: $PROBLEM_CODE"
			} | if [[ -n $USE_GIT ]]; then
			    cat >> "$TMP_GIT_COMMIT"
			else
			    cat 1>&2
			fi
		    fi

		    # if using git, add the submission directory and tarball
		    #
		    if [[ -n $USE_GIT ]]; then
			{
			    echo
			    echo "Formed: $SUBMIT_DIR/"
			    echo "Formed: $DEST_TARBALL"
			} >> "$TMP_GIT_COMMIT"
		    fi
		    add_git "$SUBMIT_DIR"
		    add_git "$DEST_TARBALL"

		    # report submission success
		    #
		    change_slot_comment "$IOCCC_USERNAME" "$SLOT_NUM" "submit file received by the IOCCC judges. Passed both txzchk and chkentry tests."
		fi
	    fi
	fi
    fi
fi


# collect any unexpected files we may have received from RMT_SLOT_PATH under ERRORS
#
unexpected_collect "$UNEXPECTED_COUNT"


# if using git, add ERRORS
#
add_git "$ERRORS"


# if using git, display the commit message
#
commit_git "$TMP_GIT_COMMIT"
if [[ $V_FLAG -ge 1 && -s $TMP_GIT_COMMIT ]]; then
    echo "$0: debug[1]: git commit message starts below" 1>&2
    cat "$TMP_GIT_COMMIT" 1>&2
    echo "$0: debug[1]: git commit message ends above" 1>&2
fi


# if using git, push any commits
#
push_git .


# All Done!!! All Done!!! -- Jessica Noll, Age 2
#
exit 0
