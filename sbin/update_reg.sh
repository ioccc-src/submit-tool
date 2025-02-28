#!/usr/bin/env bash
#
# update_reg.sh - for the newly registered, process IOCCC submit server accounts
#
# Given the submit server IOCCC password file and the list of email addresses
# who have registered for the IOCCC, we will create new IOCCC submit server accounts
# and send to those users, their IOCCC submit server and initial password, via email
# from the remote server.
#
# We will maintain a git repo, rep-ioccc under REG_DIR to record the information
# as git repo changes.
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
export VERSION="2.0.1 2025-02-27"
NAME=$(basename "$0")
export NAME
export V_FLAG=0
#
export NOOP=
export DO_NOT_PROCESS=
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
export SSH_LAST_EMAIL_MSG_SH
if [[ -z $SSH_LAST_EMAIL_MSG_SH ]]; then
    SSH_LAST_EMAIL_MSG_SH=$(type -P ssh_last_email_msg.sh)
    if [[ -z "$SSH_LAST_EMAIL_MSG_SH" ]]; then
	echo "$0: FATAL: ssh_last_email_msg.sh tool is not installed or not in \$PATH" 1>&2
	exit 5
    fi
fi
#
export SCP_PASSWD_SH
if [[ -z $SCP_PASSWD_SH ]]; then
    SCP_PASSWD_SH=$(type -P scp_passwd.sh)
    if [[ -z "$SCP_PASSWD_SH" ]]; then
	echo "$0: FATAL: scp_passwd.sh tool is not installed or not in \$PATH" 1>&2
	exit 5
    fi
fi
#
export SSH_EMAIL_PR_SH
if [[ -z $SSH_EMAIL_PR_SH ]]; then
    SSH_EMAIL_PR_SH=$(type -P ssh_email_pr.sh)
    if [[ -z "$SSH_EMAIL_PR_SH" ]]; then
	echo "$0: FATAL: ssh_email_pr.sh tool is not installed or not in \$PATH" 1>&2
	exit 5
    fi
fi
#
export SSH_MULTI_NEW_USER_SH
if [[ -z $SSH_MULTI_NEW_USER_SH ]]; then
    SSH_MULTI_NEW_USER_SH=$(type -P ssh_multi_new_user.sh)
    if [[ -z "$SSH_MULTI_NEW_USER_SH" ]]; then
	echo "$0: FATAL: ssh_multi_new_user.sh tool is not installed or not in \$PATH" 1>&2
	exit 5
    fi
fi
#
export WHO_EXTRACT_SH
if [[ -z $WHO_EXTRACT_SH ]]; then
    WHO_EXTRACT_SH=$(type -P who_extract.sh)
    if [[ -z "$WHO_EXTRACT_SH" ]]; then
	echo "$0: FATAL: who_extract.sh tool is not installed or not in \$PATH" 1>&2
	exit 5
    fi
fi
#
export FILTER_SH
if [[ -z $FILTER_SH ]]; then
    FILTER_SH=$(type -P filter.sh)
    if [[ -z "$FILTER_SH" ]]; then
	echo "$0: FATAL: filter.sh tool is not installed or not in \$PATH" 1>&2
	exit 5
    fi
fi
#
export COMM_EMAIL_SH
if [[ -z $COMM_EMAIL_SH ]]; then
    COMM_EMAIL_SH=$(type -P comm_email.sh)
    if [[ -z "$COMM_EMAIL_SH" ]]; then
	echo "$0: FATAL: comm_email.sh tool is not installed or not in \$PATH" 1>&2
	exit 5
    fi
fi
#
export SHLOCK
if [[ -z $SHLOCK ]]; then
    SHLOCK=$(type -P shlock)
    if [[ -z "$SHLOCK" ]]; then
	echo "$0: FATAL: shlock tool is not installed or not in \$PATH" 1>&2
	exit 5
    fi
fi
#
export SAVELOG
if [[ -z $SAVELOG ]]; then
    SAVELOG=$(type -P savelog)
    if [[ -z "$SAVELOG" ]]; then
	echo "$0: FATAL: savelog tool is not installed or not in \$PATH" 1>&2
	exit 5
    fi
fi
#
export REG_DIR
if [[ -z $REG_DIR ]]; then
    export REG_DIR="/usr/ioccc/reg-ioccc"
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
#
export GIT_COMMIT_NEEDED=


# git_add - If we are using git, add file to git
#
# usage:
#   git_add file
#
#   file - file to add to git
#
# returns:
#     0 ==> no errors detected
#   > 0 ==> function error number
#
# NOTE: This function does nothing if we are not using git.
#
function git_add
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
        echo "$0: Warning: in git_add: expected 1 arg, found $#" 1>&2
        return 1
    fi
    FILE="$1"

    # firewall - file must exist
    #
    if [[ ! -e $FILE ]]; then
        echo "$0: Warning: in git_add: does not exist: $MSG_FILE" 1>&2
        return 2
    fi

    # paranoia - in case TMP_STDERR is used early
    #
    if [[ -z $TMP_STDERR ]]; then
	TMP_STDERR="/dev/null"
    fi

    # git add
    #
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: in git_add: about to: $GIT_TOOL add $FILE >$TMP_STDERR 2>&1" 1>&2
    fi
    "$GIT_TOOL" add "$FILE" >"$TMP_STDERR" 2>&1
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: Warning: in git_add: $GIT_TOOL add $FILE >$TMP_STDERR 2>&1 failed, error: $status" 1>&2
	return 3
    fi

    # all OK
    #
    return 0
}


# git_commit - If we are using git, commit changes with a commit message
#
# usage:
#   git_commit msg_file
#
#   msg_file - file containing the text for the commit message
#
# returns:
#     0 ==> no errors detected
#   > 0 ==> function error number
#
# NOTE: This function does nothing if we are not using git.
#
function git_commit
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
        echo "$0: Warning: in git_commit: expected 1 arg, found $#" 1>&2
        return 1
    fi
    MSG_FILE="$1"

    # firewall - file containing the text for the commit message must not be empty
    #
    if [[ ! -s $MSG_FILE ]]; then
        echo "$0: Warning: in git_commit: MSG_FILE is not a non-empty file: $MSG_FILE" 1>&2
        return 2
    fi

    # git commit
    #
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: in git_commit: about to: $GIT_TOOL commit --allow-empty -q -F $MSG_FILE >/dev/null 2>&1" 1>&2
    fi
    "$GIT_TOOL" commit --allow-empty -q -F "$MSG_FILE" >/dev/null 2>&1
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: Warning: in git_commit: $GIT_TOOL commit --allow-empty -q -F $MSG_FILE >/dev/null 2>&1 failed, error: $status" 1>&2
	return 3
    fi

    # all OK
    #
    return 0
}


# git_push - If we are using git, push commit(s) to repo
#
# usage:
#   git_push .
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
function git_push
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
        echo "$0: Warning: in git_push: expected 1 arg, found $#" 1>&2
        return 1
    fi
    IGNORED="$1"

    # git push
    #
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: in git_push: about to: $GIT_TOOL push >/dev/null 2>&1" 1>&2
    fi
    if [[ $V_FLAG -ge 5 ]]; then
	# This debug message is to silence shellcheck warning 2034
	echo "$0: debug[5]: in git_push: ignored arg is: $IGNORED" 1>&2
    fi
    "$GIT_TOOL" push >/dev/null 2>&1
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: Warning: in git_push: $GIT_TOOL push >/dev/null 2>&1 failed, error: $status" 1>&2
	return 2
    fi

    # all OK
    #
    return 0
}


# git_exit - clone out a session with an error message and exit code
#
# usage:
#   git_exit exit_code error_msg ...
#
#   exit_code - exit with this code
#   error_msg ... - error message to record
#
# NOTE: This function does not return
#
function git_exit
{
    local EXIT_CODE;	    # how to exit
    local re;		    # integer regex

    # parse args
    #
    if [[ $# -le 2 ]]; then
        echo "$0: Warning: in git_exit: expected 2 or more args, found $#" 1>&2
        echo "$0: ERROR: in git_exit: forcing exit 200" 1>&2
        exit 200
    fi
    EXIT_CODE="$1"
    shift

    # write error_msg to stderr
    #
    echo "$@" 1>&2

    # firewall - EXIT_CODE must be an integer >= 0
    #
    re='^[0-9]+$'
    if ! [[ $EXIT_CODE =~ $re ]] ; then
	echo "$0: Warning: in git_exit: exit_code arg is not an integer >= 0: $EXIT_CODE" 1>&2
	echo "$0: ERROR: in git_exit: will set code to  201" 1>&2
	EXIT_CODE="201"	    # exit 201
    fi

    # we can only perform git operations if USE_GIT and we have a non-empty TMP_GIT_COMMIT file
    #
    if [[ -n $USE_GIT && -n $TMP_GIT_COMMIT && -s $TMP_GIT_COMMIT ]]; then

	# add the error message to git commit message
	#
	{
	    echo
	    echo "$0: Warning: in git_exit: error message follows"
	    echo
	    echo "$@"
	} >> "$TMP_GIT_COMMIT"
	if [[ -n $TMP_STDERR && -s $TMP_STDERR ]]; then
	    {
		echo
		echo "$0: Warning: in git_exit: stderr output starts below"
		cat "$TMP_STDERR"
		echo "$0: Warning: in git_exit: stderr output ends above"
	    } >> "$TMP_GIT_COMMIT"
	fi

	# git commit, even if the commit is empty
	#
	if [[ $V_FLAG -ge 1 ]]; then
	    echo "$0: debug[1]: in git_commit: about to: $GIT_TOOL commit --allow-empty -q -F $TMP_GIT_COMMIT >/dev/null 2>&1" 1>&2
	fi
	"$GIT_TOOL" commit --allow-empty -q -F "$TMP_GIT_COMMIT" >/dev/null 2>&1
	status="$?"
	if [[ $status -ne 0 ]]; then
	    echo "$0: Warning: in git_commit: $GIT_TOOL commit --allow-empty -q -F $TMP_GIT_COMMIT >/dev/null 2>&1 failed, error: $status" 1>&2
	fi

	# push commit
	#
	git_push .
    fi

    # exit
    #
    exit "$EXIT_CODE"
}


# replace_file_git_add - replace a dest file and git add if the src file is different
#
# usage:
#   replace_file_git_add src dest
#
#   src - source file to compare
#   dest - destination file to update if src file as a non-empty file that different from the dest file
#
function replace_file_git_add
{
    local SRC;	    # 1st file
    local DEST;	    # 2nd file

    # parse args
    #
    if [[ $# -le 2 ]]; then
        git_exit 202 "$0: Warning: in replace_file_git_add: expected 2 or more args, found $#" 1>&2
    fi
    SRC="$1"
    DEST="$2"

    # do nothing if src is not a readable non-empty file
    #
    if [[ -z $SRC || ! -e $SRC || ! -f $SRC || ! -s $SRC ]]; then
	return
    fi

    # do nothing if no dest arg
    #
    if [[ -z $DEST ]]; then
	return
    fi

    # update dest if different
    #
    if ! cmp "$SRC" "$DEST"; then

	# replace dest with src
	#
	mv -f "$SRC" "$DEST"
	status="$?"
	if [[ $status -ne 0 ]]; then
	    git_exit 1 "$0: ERROR: in replace_file_git_add: mv -f $SRC $DEST failed, error: $status" 1>&2
	fi

	# add the replaced dest
	#
	git_add "$DEST"
	GIT_COMMIT_NEEDED="true"
	if [[ $V_FLAG -ge 3 ]]; then
	    echo "$0: debug[3]: in replace_file_git_add: updated via git: $DEST" 1>&2
	fi
    fi
    return
}


# usage
#
export USAGE="usage: $0 [-h] [-v level] [-V] [-n] [-N] [-t rmt_topdir] [-i ioccc.rc] [-I]
	[-p rmt_port] [-u rmt_user] [-H rmt_host]
	[-l ssh_last_email_msg] [-s scp_passwd] [-e ssh_email_pr] [-m ssh_multi_new_user]
	[-w who_extract] [-f filter] [-c comm_email] [-L shlock] [-S savelog] [-r regdir]

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

	-l ssh_last_email_msg	use local ssh_last_email_msg tool to read last email (def: $SSH_LAST_EMAIL_MSG_SH)
	-s scp_passwd		use local scp_passwd to copy IOCCC password (def: $SCP_PASSWD_SH)
	-e ssh_email_pr		use local ssh_email_pr to collect email addresses (def: $SSH_EMAIL_PR_SH)
	-m ssh_multi_new_user	use local ssh_multi_new_user to process new user accounts (def: $SSH_MULTI_NEW_USER_SH)

	-w who_extract		use local who_extract to extract email from Ecartis who command (def: $WHO_EXTRACT_SH)
	-f filter		use local filter to filter email addresses (def: $FILTER_SH)
	-c comm_email		use local comm_email to print email from 2nd file not in 1st file (def: $COMM_EMAIL_SH)
	-L shlock		use local shlock tool to lock a file (def: $SHLOCK)
	-S savelog		use local savelog tool (def: $SAVELOG)

	-r regdir		cd to the regdir before running (def: stay in $REG_DIR)

Exit codes:
     0        all OK
     1        some internal file missing or not writable, some internal tool exited non-zero or returned a malformed response
     2        -h and help string printed or -V and version string printed
     3        command line error
     4        source of ioccc.rc file failed
     5        some critical local executable tool not found
     6        regdir is not a directory, or is missing one of etc, list, log, mail and/or work
 >= 10        internal error

$NAME version: $VERSION"


# parse command line
#
while getopts :hv:VnNt:T:i:Ip:u:H:l:s:e:m:w:f:c:L:S:r: flag; do
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
    l) SSH_LAST_EMAIL_MSG_SH="$OPTARG"
	;;
    s) SCP_PASSWD_SH="$OPTARG"
	;;
    e) SSH_EMAIL_PR_SH="$OPTARG"
	;;
    m) SSH_MULTI_NEW_USER_SH="$OPTARG"
	;;
    w) WHO_EXTRACT_SH="$OPTARG"
	;;
    f) FILTER_SH="$OPTARG"
	;;
    c) COMM_EMAIL_SH="$OPTARG"
	;;
    L) SHLOCK="$OPTARG"
	;;
    S) SAVELOG="$OPTARG"
	;;
    r) REG_DIR="$OPTARG"
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


# -n turns off git operations
#
if [[ -n $NOOP ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[3]: use of -n will disable git operatons" 1>&2
    fi
    USE_GIT=
fi


# determine date time stamps
#
export NOW DATE_UTC SECS
NOW=$(date '+%Y%m%d.%H%M%S')
DATE_UTC=$(date -u '+%F %T.%N UTC')
SECS=$(date '+%s')


# set important paths under REG_DIR
#
export IOCCCPASSWD_JSON="$REG_DIR/etc/iocccpasswd.json"
if [[ ! -f $IOCCCPASSWD_JSON && -z $NOOP ]]; then
    touch "$IOCCCPASSWD_JSON"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: cannot touch $IOCCCPASSWD_JSON failed, error: $status" 1>&2
	exit 1
    fi
fi
#
export WHO_IOCCC="$REG_DIR/mail/who-ioccc"
if [[ ! -f $WHO_IOCCC && -z $NOOP ]]; then
    touch "$WHO_IOCCC"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: cannot touch $WHO_IOCCC failed, error: $status" 1>&2
	exit 1
    fi
fi
#
export FREELISTS_LST="$REG_DIR/list/freelists.lst"
if [[ ! -f $FREELISTS_LST && -z $NOOP ]]; then
    touch "$FREELISTS_LST"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: cannot touch $FREELISTS_LST failed, error: $status" 1>&2
	exit 1
    fi
fi
#
export FILTER_SED="$REG_DIR/list/filter.sed"
if [[ ! -f $FILTER_SED && -z $NOOP ]]; then
    touch "$FILTER_SED"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: cannot touch $FILTER_SED failed, error: $status" 1>&2
	exit 1
    fi
fi
#
export REGISTER_LST="$REG_DIR/list/register.lst"
if [[ ! -f $REGISTER_LST && -z $NOOP ]]; then
    touch "$REGISTER_LST"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: cannot touch $REGISTER_LST failed, error: $status" 1>&2
	exit 1
    fi
fi
#
export IOCCCPASSWD_LST="$REG_DIR/list/iocccpasswd.lst"
if [[ ! -f $IOCCCPASSWD_LST && -z $NOOP ]]; then
    touch "$IOCCCPASSWD_LST"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: cannot touch $IOCCCPASSWD_LST failed, error: $status" 1>&2
	exit 1
    fi
fi
#
export WORK_DIR="$REG_DIR/work"
if [[ ! -d $WORK_DIR ]]; then
    echo "$0: ERROR: work is not a directory: $WORK_DIR" 1>&2
    exit 1
fi
#
# NOTE: We will create the run list of email addresses later on
export RUN="$WORK_DIR/run"
#
export LOCK="$WORK_DIR/run.lock"
if [[ ! -f $LOCK && -z $NOOP ]]; then
    touch "$LOCK"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: cannot touch $LOCK failed, error: $status" 1>&2
	exit 1
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
    echo "$0: debug[3]: RMT_TMPDIR=$RMT_TMPDIR" 1>&2
    echo "$0: debug[3]: IOCCC_RC=$IOCCC_RC" 1>&2
    echo "$0: debug[3]: CAP_I_FLAG=$CAP_I_FLAG" 1>&2
    echo "$0: debug[3]: RMT_PORT=$RMT_PORT" 1>&2
    echo "$0: debug[3]: USER_NAME=$USER_NAME" 1>&2
    echo "$0: debug[3]: RMT_USER=$RMT_USER" 1>&2
    echo "$0: debug[3]: SERVER=$SERVER" 1>&2
    echo "$0: debug[3]: SSH_LAST_EMAIL_MSG_SH=$SSH_LAST_EMAIL_MSG_SH" 1>&2
    echo "$0: debug[3]: SCP_PASSWD_SH=$SCP_PASSWD_SH" 1>&2
    echo "$0: debug[3]: SSH_EMAIL_PR_SH=$SSH_EMAIL_PR_SH" 1>&2
    echo "$0: debug[3]: SSH_MULTI_NEW_USER_SH=$SSH_MULTI_NEW_USER_SH" 1>&2
    echo "$0: debug[3]: WHO_EXTRACT_SH=$WHO_EXTRACT_SH" 1>&2
    echo "$0: debug[3]: FILTER_SH=$FILTER_SH" 1>&2
    echo "$0: debug[3]: COMM_EMAIL_SH=$COMM_EMAIL_SH" 1>&2
    echo "$0: debug[3]: SHLOCK=$SHLOCK" 1>&2
    echo "$0: debug[3]: SAVELOG=$SAVELOG" 1>&2
    echo "$0: debug[3]: REG_DIR=$REG_DIR" 1>&2
    echo "$0: debug[3]: GIT_TOOL=$GIT_TOOL" 1>&2
    echo "$0: debug[3]: USE_GIT=$USE_GIT" 1>&2
    echo "$0: debug[3]: GIT_COMMIT_NEEDED=$GIT_COMMIT_NEEDED" 1>&2
    echo "$0: debug[3]: NOW=$NOW" 1>&2
    echo "$0: debug[3]: DATE_UTC=$DATE_UTC" 1>&2
    echo "$0: debug[3]: SECS=$SECS" 1>&2
    echo "$0: debug[3]: IOCCCPASSWD_JSON=$IOCCCPASSWD_JSON" 1>&2
    echo "$0: debug[3]: WHO_IOCCC=$WHO_IOCCC" 1>&2
    echo "$0: debug[3]: FREELISTS_LST=$FREELISTS_LST" 1>&2
    echo "$0: debug[3]: FILTER_SED=$FILTER_SED" 1>&2
    echo "$0: debug[3]: REGISTER_LST=$REGISTER_LST" 1>&2
    echo "$0: debug[3]: IOCCCPASSWD_LST=$IOCCCPASSWD_LST" 1>&2
    echo "$0: debug[3]: WORK_DIR=$WORK_DIR" 1>&2
    echo "$0: debug[3]: RUN=$RUN" 1>&2
    echo "$0: debug[3]: LOCK=$LOCK" 1>&2
fi


# firewall - GIT_TOOL must be executable if git is to be used
#
if [[ -n $USE_GIT ]]; then
    if [[ ! -x $GIT_TOOL ]]; then
	echo "$0: ERROR: git tool not executable: $GIT_TOOL" 1>&2
	exit 5
    fi
fi


# REG_DIR must be under git control to use git
#

if [[ -n $USE_GIT ]]; then
    if "$GIT_TOOL" -C "$REG_DIR" rev-parse >/dev/null 2>&1; then

	# While REG_DIR is under git control,
	# we do NOT want to use git under common IOCCC related repos
	# that certain well known files or directories.
	#
	for i in jparse.c mkiocccentry.c F iocccsubmit 1984; do
	    if [[ -e $REG_DIR/$i ]]; then
		echo "$0: ERROR: found $REG_DIR/$i, the directory appears to be another common IOCCC related repo" 1>&2
		exit 6
	    fi
	done
    else
	echo "$0: ERROR: $GIT_TOOL -C $REG_DIR rev-parse >/dev/null 2>&1 is false, cannot use git" 1>&2
	exit 6
    fi
fi


# move to regdir is regdir is not .
#
if [[ $REG_DIR != "." ]]; then
    if [[ $V_FLAG -ge 3 ]]; then
	echo "$0: debug[3]: about to cd $REG_DIR" 1>&2
    fi
    export CD_FAILED=""
    cd "$REG_DIR" || CD_FAILED="true"
    if [[ -n $CD_FAILED ]]; then
	echo "$0: ERROR: cd $REG_DIR failed" 1>&2
	exit 6
    fi
fi
if [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: current working directory is: $(/bin/pwd)" 1>&2
fi


# firewall - SSH_LAST_EMAIL_MSG_SH must be executable
#
if [[ ! -x $SSH_LAST_EMAIL_MSG_SH ]]; then
    echo "$0: ERROR: ssh_last_email_msg.sh tool not executable: $SSH_LAST_EMAIL_MSG_SH" 1>&2
    exit 5
fi


# firewall - SCP_PASSWD_SH must be executable
#
if [[ ! -x $SCP_PASSWD_SH ]]; then
    echo "$0: ERROR: scp_passwd.sh tool not executable: $SCP_PASSWD_SH" 1>&2
    exit 5
fi


# firewall - SSH_EMAIL_PR_SH must be executable
#
if [[ ! -x $SSH_EMAIL_PR_SH ]]; then
    echo "$0: ERROR: ssh_email_pr.sh tool not executable: $SSH_EMAIL_PR_SH" 1>&2
    exit 5
fi


# firewall - SSH_MULTI_NEW_USER_SH must be executable
#
if [[ ! -x $SSH_MULTI_NEW_USER_SH ]]; then
    echo "$0: ERROR: ssh_multi_new_user.sh tool not executable: $SSH_MULTI_NEW_USER_SH" 1>&2
    exit 5
fi


# firewall - WHO_EXTRACT_SH must be executable
#
if [[ ! -x $WHO_EXTRACT_SH ]]; then
    echo "$0: ERROR: who_extract.sh tool not executable: $WHO_EXTRACT_SH" 1>&2
    exit 5
fi


# firewall - FILTER_SH must be executable
#
if [[ ! -x $FILTER_SH ]]; then
    echo "$0: ERROR: filter.sh tool not executable: $FILTER_SH" 1>&2
    exit 5
fi


# firewall - COMM_EMAIL_SH must be executable
#
if [[ ! -x $COMM_EMAIL_SH ]]; then
    echo "$0: ERROR: comm_email.sh tool not executable: $COMM_EMAIL_SH" 1>&2
    exit 5
fi


# firewall - SHLOCK must be executable
#
if [[ ! -x $SHLOCK ]]; then
    echo "$0: ERROR: shlock tool not executable: $SHLOCK" 1>&2
    exit 5
fi


# firewall - regdir must be a directory
#
if [[ ! -d $REG_DIR ]]; then
    echo "$0: ERROR: regdir is not a directory: $REG_DIR" 1>&2
    exit 6
fi

#
# firewall - Must have these writable sub-directories
#
for i in etc list mail work; do
    if [[ ! -d $i || ! -w $i ]]; then
	echo "$0: ERROR: not a directory: $REG_DIR/$i" 1>&2
	exit 6
    fi
done


# Must have a non-empty DO.NOT.DISTRIBUTE readable file
#
if [[ ! -e $REG_DIR/DO.NOT.DISTRIBUTE ]]; then
    echo "$0: ERROR $REG_DIR/DO.NOT.DISTRIBUTE does not exist, disabling use of git" 1>&2
    exit 6
elif [[ ! -f $REG_DIR/DO.NOT.DISTRIBUTE ]]; then
    echo "$0: ERROR: $REG_DIR/DO.NOT.DISTRIBUTE is not a file, disabling use of git" 1>&2
    exit 6
elif [[ ! -r $REG_DIR/DO.NOT.DISTRIBUTE ]]; then
    echo "$0: ERROR: $REG_DIR/DO.NOT.DISTRIBUTE is not a readable file, disabling use of git" 1>&2
    exit 6
elif [[ ! -s $REG_DIR/DO.NOT.DISTRIBUTE ]]; then
    echo "$0: ERROR: $REG_DIR/DO.NOT.DISTRIBUTE is not a non-empty readable file, disabling use of git" 1>&2
    exit 6
fi


# -N stops early before any processing is performed
#
if [[ -n $DO_NOT_PROCESS ]]; then
    if [[ $V_FLAG -ge 3 ]]; then
	echo "$0: debug[3]: arguments parsed, -N given, exiting 0" 1>&2
    fi
    exit 0
fi


# obtain the lock
#
export LOCK_CONTENTS
if [[ -z $NOOP ]]; then
    if ! "$SHLOCK" -p "$$" -f "$LOCK"; then
	LOCK_CONTENTS=$(< "$LOCK")
	echo "$0: ERROR: locked by process: $LOCK_CONTENTS" 1>&2
	echo 1
    fi
    trap 'rm -f $LOCK; exit' 0 1 2 3 15
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did obtain the lock: $LOCK" 1>&2
fi


# form temporary stderr collection file
#
export TMP_STDERR="$TMPDIR/.tmp.$NAME.STDERR.$$.tmp"
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 3 ]]; then
	echo  "$0: debug[3]: temporary stderr collection file: $TMP_STDERR" 1>&2
    fi
    trap 'rm -f $LOCK $TMP_STDERR; exit' 0 1 2 3 15
    rm -f "$TMP_STDERR"
    if [[ -e $TMP_STDERR ]]; then
	echo "$0: ERROR: cannot remove stderr collection file: $TMP_STDERR" 1>&2
	exit 203
    fi
    : >  "$TMP_STDERR"
    if [[ ! -e $TMP_STDERR ]]; then
	echo "$0: ERROR: cannot create stderr collection file: $TMP_STDERR" 1>&2
	exit 204
    fi
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not form temporary stderr collection file: $TMP_STDERR" 1>&2
fi
if [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: TMP_STDERR=$TMP_STDERR" 1>&2
fi


# form temporary git commit message
#
export TMP_GIT_COMMIT="$REG_DIR/.tmp.$NAME.GIT_COMMIT.$$.tmp"
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 3 ]]; then
	echo  "$0: debug[3]: temporary git commit message file: $TMP_GIT_COMMIT" 1>&2
    fi
    trap 'rm -f $LOCK $TMP_STDERR $TMP_GIT_COMMIT; exit' 0 1 2 3 15
    rm -f "$TMP_GIT_COMMIT"
    if [[ -e $TMP_GIT_COMMIT ]]; then
	echo "$0: ERROR: cannot remove git commit message file: $TMP_GIT_COMMIT" 1>&2
	exit 205
    fi
    {
	echo "run of $DATE_UTC ($SECS)"
	echo
	echo "This run of $NOW was produced by $NAME"
    } > "$TMP_GIT_COMMIT"
    if [[ ! -s $TMP_GIT_COMMIT ]]; then
	echo "$0: ERROR: cannot create git commit message file: $TMP_GIT_COMMIT" 1>&2
	exit 206
    fi

    # NOTE: We can now call git_exit if needed

elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not form git commit message: $TMP_GIT_COMMIT" 1>&2
fi
if [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: TMP_GIT_COMMIT=$TMP_GIT_COMMIT" 1>&2
fi


# form temporary iocccpasswd.json file
#
export TMP_IOCCCPASSWD_JSON="$REG_DIR/.tmp.$NAME.IOCCCPASSWD_JSON.$$.tmp"
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 3 ]]; then
	echo  "$0: debug[3]: temporary iocccpasswd.json file: $TMP_IOCCCPASSWD_JSON" 1>&2
    fi
    trap 'rm -f $LOCK $TMP_STDERR $TMP_GIT_COMMIT $TMP_IOCCCPASSWD_JSON; exit' 0 1 2 3 15
    rm -f "$TMP_IOCCCPASSWD_JSON"
    if [[ -e $TMP_IOCCCPASSWD_JSON ]]; then
	git_exit 1 "$0: ERROR: cannot remove iocccpasswd.json file: $TMP_IOCCCPASSWD_JSON"
    fi
    : >  "$TMP_IOCCCPASSWD_JSON"
    if [[ ! -e $TMP_IOCCCPASSWD_JSON ]]; then
	git_exit 1 "$0: ERROR: cannot create iocccpasswd.json file: $TMP_IOCCCPASSWD_JSON"
    fi
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not form temporary iocccpasswd.json file: $TMP_IOCCCPASSWD_JSON" 1>&2
fi
if [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: TMP_IOCCCPASSWD_JSON=$TMP_IOCCCPASSWD_JSON" 1>&2
fi


# update iocccpasswd.json if needed
#
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: $SCP_PASSWD_SH $TMP_IOCCCPASSWD_JSON 2>$TMP_STDERR" 1>&2
    fi
    "$SCP_PASSWD_SH" "$TMP_IOCCCPASSWD_JSON" 2>"$TMP_STDERR"
    status="$?"
    if [[ $status -ne 0 ]]; then
	git_exit 1 "$0: ERROR: $SCP_PASSWD_SH $TMP_IOCCCPASSWD_JSON 2>$TMP_STDERR failed, error: $status"
    fi
    replace_file_git_add "$TMP_IOCCCPASSWD_JSON" "$IOCCCPASSWD_JSON"
    rm -f "$TMP_IOCCCPASSWD_JSON" # temp file no longer needed
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not update iocccpasswd.json file: $IOCCCPASSWD_JSON" 1>&2
fi


# form temporary iocccpasswd.lst file
#
export TMP_IOCCCPASSWD_LST="$REG_DIR/.tmp.$NAME.IOCCCPASSWD_LST.$$.tmp"
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 3 ]]; then
	echo  "$0: debug[3]: temporary iocccpasswd.lst file: $TMP_IOCCCPASSWD_LST" 1>&2
    fi
    trap 'rm -f $LOCK $TMP_STDERR $TMP_GIT_COMMIT $TMP_IOCCCPASSWD_LST; exit' 0 1 2 3 15
    rm -f "$TMP_IOCCCPASSWD_LST"
    if [[ -e $TMP_IOCCCPASSWD_LST ]]; then
	git_exit 1 "$0: ERROR: cannot remove iocccpasswd.lst file: $TMP_IOCCCPASSWD_LST"
    fi
    : >  "$TMP_IOCCCPASSWD_LST"
    if [[ ! -e $TMP_IOCCCPASSWD_LST ]]; then
	git_exit 1 "$0: ERROR: cannot create iocccpasswd.lst file: $TMP_IOCCCPASSWD_LST"
    fi
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not form temporary iocccpasswd.lst file: $TMP_IOCCCPASSWD_LST" 1>&2
fi
if [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: TMP_IOCCCPASSWD_LST=$TMP_IOCCCPASSWD_LST" 1>&2
fi


# update iocccpasswd.lst if needed
#
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: $SCP_PASSWD_SH $TMP_IOCCCPASSWD_LST 2>$TMP_STDERR" 1>&2
    fi
    "$SSH_EMAIL_PR_SH" "$TMP_IOCCCPASSWD_LST" 2>"$TMP_STDERR"
    status="$?"
    if [[ $status -ne 0 ]]; then
	git_exit 1 "$0: ERROR: $SCP_PASSWD_SH $TMP_IOCCCPASSWD_LST 2>$TMP_STDERR failed, error: $status"
    fi
    replace_file_git_add "$TMP_IOCCCPASSWD_LST" "$IOCCCPASSWD_LST"
    rm -f "$TMP_IOCCCPASSWD_LST" # temp file no longer needed
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not update iocccpasswd.lst file: $IOCCCPASSWD_LST" 1>&2
fi


# form temporary who-ioccc file
#
export TMP_WHO_IOCCC="$REG_DIR/.tmp.$NAME.WHO_IOCCC.$$.tmp"
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 3 ]]; then
	echo  "$0: debug[3]: temporary who-ioccc file: $TMP_WHO_IOCCC" 1>&2
    fi
    trap 'rm -f $LOCK $TMP_STDERR $TMP_GIT_COMMIT $TMP_WHO_IOCCC; exit' 0 1 2 3 15
    rm -f "$TMP_WHO_IOCCC"
    if [[ -e $TMP_WHO_IOCCC ]]; then
	git_exit 1 "$0: ERROR: cannot remove who-ioccc file: $TMP_WHO_IOCCC"
    fi
    : >  "$TMP_WHO_IOCCC"
    if [[ ! -e $TMP_WHO_IOCCC ]]; then
	git_exit 1 "$0: ERROR: cannot create who-ioccc file: $TMP_WHO_IOCCC"
    fi
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not form temporary who-ioccc file: $TMP_WHO_IOCCC" 1>&2
fi
if [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: TMP_WHO_IOCCC=$TMP_WHO_IOCCC" 1>&2
fi


# update who-ioccc if needed
#
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: $SCP_PASSWD_SH > $TMP_WHO_IOCCC 2>$TMP_STDERR" 1>&2
    fi
    "$SSH_EMAIL_PR_SH" > "$TMP_WHO_IOCCC" 2>"$TMP_STDERR"
    status="$?"
    if [[ $status -ne 0 ]]; then
	git_exit 1 "$0: ERROR: $SCP_PASSWD_SH > $TMP_WHO_IOCCC 2>$TMP_STDERR failed, error: $status"
    fi
    replace_file_git_add "$TMP_WHO_IOCCC" "$WHO_IOCCC"
    rm -f "$TMP_WHO_IOCCC" # temp file no longer needed
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not update who-ioccc file: $WHO_IOCCC" 1>&2
fi


# form temporary freelists.lst file
#
export TMP_FREELISTS_LST="$REG_DIR/.tmp.$NAME.FREELISTS_LST.$$.tmp"
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 3 ]]; then
	echo  "$0: debug[3]: temporary freelists.lst file: $TMP_FREELISTS_LST" 1>&2
    fi
    trap 'rm -f $LOCK $TMP_STDERR $TMP_GIT_COMMIT $TMP_FREELISTS_LST; exit' 0 1 2 3 15
    rm -f "$TMP_FREELISTS_LST"
    if [[ -e $TMP_FREELISTS_LST ]]; then
	git_exit 1 "$0: ERROR: cannot remove freelists.lst file: $TMP_FREELISTS_LST"
    fi
    : >  "$TMP_FREELISTS_LST"
    if [[ ! -e $TMP_FREELISTS_LST ]]; then
	git_exit 1 "$0: ERROR: cannot create freelists.lst file: $TMP_FREELISTS_LST"
    fi
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not form temporary freelists.lst file: $TMP_FREELISTS_LST" 1>&2
fi
if [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: TMP_FREELISTS_LST=$TMP_FREELISTS_LST" 1>&2
fi


# update freelists.lst if needed
#
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: $WHO_EXTRACT_SH $WHO_IOCCC $TMP_FREELISTS_LST 2>$TMP_STDERR" 1>&2
    fi
    "$WHO_EXTRACT_SH" "$WHO_IOCCC" "$TMP_FREELISTS_LST" 2>"$TMP_STDERR"
    status="$?"
    if [[ $status -ne 0 ]]; then
	git_exit 1 "$0: ERROR: $WHO_EXTRACT_SH $WHO_IOCCC $TMP_FREELISTS_LST 2>$TMP_STDERR failed, error: $status"
    fi
    replace_file_git_add "$TMP_FREELISTS_LST" "$FREELISTS_LST"
    rm -f "$TMP_FREELISTS_LST" # temp file no longer needed
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not update freelists.lst file: $FREELISTS_LST" 1>&2
fi


# form temporary regsier.lst file
#
export TMP_REGISTER_LST="$REG_DIR/.tmp.$NAME.REGISTER_LST.$$.tmp"
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 3 ]]; then
	echo  "$0: debug[3]: temporary regsier.lst file: $TMP_REGISTER_LST" 1>&2
    fi
    trap 'rm -f $LOCK $TMP_STDERR $TMP_GIT_COMMIT $TMP_REGISTER_LST; exit' 0 1 2 3 15
    rm -f "$TMP_REGISTER_LST"
    if [[ -e $TMP_REGISTER_LST ]]; then
	git_exit 1 "$0: ERROR: cannot remove regsier.lst file: $TMP_REGISTER_LST"
    fi
    : >  "$TMP_REGISTER_LST"
    if [[ ! -e $TMP_REGISTER_LST ]]; then
	git_exit 1 "$0: ERROR: cannot create regsier.lst file: $TMP_REGISTER_LST"
    fi
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not form temporary regsier.lst file: $TMP_REGISTER_LST" 1>&2
fi
if [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: TMP_REGISTER_LST=$TMP_REGISTER_LST" 1>&2
fi


# update regsier.lst if needed
#
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: $FILTER_SH $FREELISTS_LST $FILTER_SED > $REGISTER_LST 2>$TMP_STDERR" 1>&2
    fi
    "$FILTER_SH" "$FREELISTS_LST" "$FILTER_SED" > "$REGISTER_LST" 2>"$TMP_STDERR"
    status="$?"
    if [[ $status -ne 0 ]]; then
	git_exit 1 "$0: ERROR: $FILTER_SH $FREELISTS_LST $FILTER_SED > $REGISTER_LST 2>$TMP_STDERR failed, error: $status"
    fi
    replace_file_git_add "$TMP_REGISTER_LST" "$REGISTER_LST"
    rm -f "$TMP_REGISTER_LST" # temp file no longer needed
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not update regsier.lst file: $REGISTER_LST" 1>&2
fi


# form temporary run file
#
export TMP_RUN_LST="$WORK_DIR/.tmp.$NAME.RUN.$$.tmp"
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 3 ]]; then
	echo  "$0: debug[3]: temporary run file: $TMP_RUN_LST" 1>&2
    fi
    trap 'rm -f $LOCK $TMP_STDERR $TMP_GIT_COMMIT $TMP_RUN_LST; exit' 0 1 2 3 15
    rm -f "$TMP_RUN_LST"
    if [[ -e $TMP_RUN_LST ]]; then
	git_exit 1 "$0: ERROR: cannot remove run file: $TMP_RUN_LST"
    fi
    : >  "$TMP_RUN_LST"
    if [[ ! -e $TMP_RUN_LST ]]; then
	git_exit 1 "$0: ERROR: cannot create run file: $TMP_RUN_LST"
    fi
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not form temporary run file: $TMP_RUN_LST" 1>&2
fi
if [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: TMP_RUN_LST=$TMP_RUN_LST" 1>&2
fi


# determine if we have any email addresses to process
#
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: $COMM_EMAIL_SH $REGISTER_LST $IOCCCPASSWD_LST $TMP_RUN_LST 2>$TMP_STDERR" 1>&2
    fi
    "$COMM_EMAIL_SH" "$REGISTER_LST" "$IOCCCPASSWD_LST" "$TMP_RUN_LST" 2>"$TMP_STDERR"
    status="$?"
    if [[ $status -ne 0 ]]; then
	git_exit 1 "$0: ERROR: $COMM_EMAIL_SH $REGISTER_LST $IOCCCPASSWD_LST $TMP_RUN_LST 2>$TMP_STDERR failed, error: $status"
    fi
    # keep the TMP_RUN_LST for the next section
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not form run list: $TMP_RUN_LST" 1>&2
fi


# process run if we have email addresses to process
#
if [[ -z $NOOP ]]; then
    if [[ -s $TMP_RUN_LST ]]; then

	# process the email addresses we collected
	#
	if [[ $V_FLAG -ge 1 ]]; then
	    echo "$0: debug[1]: about to: $SSH_MULTI_NEW_USER_SH $TMP_RUN_LST 2>$TMP_STDERR" 1>&2
	fi
	"$SSH_MULTI_NEW_USER_SH" "$TMP_RUN_LST" 2>"$TMP_STDERR"
	status="$?"
	if [[ $status -ne 0 ]]; then
	    git_exit 1 "$0: ERROR: $SSH_MULTI_NEW_USER_SH $TMP_RUN_LST 2>$TMP_STDERR failed, error: $status"
	fi

	# move the run list into place for log rotation
	#
	if [[ $V_FLAG -ge 1 ]]; then
	    echo "$0: debug[1]: about to: mv -f $TMP_RUN_LST $RUN 2>$TMP_STDERR" 1>&2
	fi
	mv -f "$TMP_RUN_LST" "$RUN" 2>"$TMP_STDERR"
	status="$?"
	if [[ $status -ne 0 ]]; then
	    git_exit 1 "$0: ERROR: mv -f $TMP_RUN_LST $RUN 2>$TMP_STDERR failed, error: $status"
	fi

	# savelog the run
	#
	if [[ $V_FLAG -ge 1 ]]; then
	    echo "$0: debug[1]: about to: $SAVELOG -c 0 -T $RUN 2>$TMP_STDERR" 1>&2
	fi
	"$SAVELOG" -c 0 -T "$RUN" 2>"$TMP_STDERR"
	status="$?"
	if [[ $status -ne 0 ]]; then
	    git_exit 1 "$0: ERROR: $SAVELOG -c 0 -T $RUN 2>$TMP_STDERR failed, error: $status"
	fi

	# remove the TMP_RUN_LST list
	#
	rm -f "$TMP_RUN_LST"

	# put and all files under WORK_DIR under git now that the work has been completed
	#
	git add "$WORK_DIR"
	GIT_COMMIT_NEEDED="true"

    elif [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: the run list if empty: $TMP_RUN_LST" 1>&2
    fi
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not process run list: $TMP_RUN_LST" 1>&2
fi


# commit the changes if needed
#
if [[ -z $NOOP ]]; then
    if [[ -n $USE_GIT && -n $GIT_COMMIT_NEEDED && -n $TMP_GIT_COMMIT && -s $TMP_GIT_COMMIT ]]; then
	git_commit "$TMP_GIT_COMMIT"
	status="$?"
	if [[ $status -ne 0 ]]; then
	    git_exit 1 "$0: ERROR: git_commit $TMP_GIT_COMMIT failed, error: $status"
	fi
    fi
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not git_commit $$TMP_GIT_COMMIT" 1>&2
fi


# if using git, display the commit message
#
if [[ $V_FLAG -ge 1 && -s $TMP_GIT_COMMIT ]]; then
    echo "$0: debug[1]: git commit message starts below" 1>&2
    cat "$TMP_GIT_COMMIT" 1>&2
    echo "$0: debug[1]: git commit message ends above" 1>&2
fi


# if using git, push any commits
#
if [[ -z $NOOP ]]; then
    if [[ -n $USE_GIT ]]; then
	git_push .
	status="$?"
	if [[ $status -ne 0 ]]; then
	    git_exit 1 "$0: ERROR: git_push . failed, error: $status"
	fi
    fi
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not git_push ." 1>&2
fi


# restart temporary git commit message
#
if [[ -z $NOOP ]]; then
    {
	echo "after run of $DATE_UTC ($SECS)"
	echo
    } > "$TMP_GIT_COMMIT"
    if [[ ! -s $TMP_GIT_COMMIT ]]; then
	echo "$0: ERROR: cannot create git commit message file: $TMP_GIT_COMMIT" 1>&2
	exit 207
    fi

elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not restart git commit message: $TMP_GIT_COMMIT" 1>&2
fi


# re-form temporary iocccpasswd.json file
#
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 3 ]]; then
	echo  "$0: debug[3]: again: temporary iocccpasswd.json file: $TMP_IOCCCPASSWD_JSON" 1>&2
    fi
    trap 'rm -f $LOCK $TMP_STDERR $TMP_GIT_COMMIT $TMP_IOCCCPASSWD_JSON; exit' 0 1 2 3 15
    rm -f "$TMP_IOCCCPASSWD_JSON"
    if [[ -e $TMP_IOCCCPASSWD_JSON ]]; then
	git_exit 1 "$0: ERROR: cannot re-remove iocccpasswd.json file: $TMP_IOCCCPASSWD_JSON"
    fi
    : >  "$TMP_IOCCCPASSWD_JSON"
    if [[ ! -e $TMP_IOCCCPASSWD_JSON ]]; then
	git_exit 1 "$0: ERROR: cannot re-create iocccpasswd.json file: $TMP_IOCCCPASSWD_JSON"
    fi
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not re-form temporary iocccpasswd.json file: $TMP_IOCCCPASSWD_JSON" 1>&2
fi


# update iocccpasswd.json again
#
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: again: $SCP_PASSWD_SH $TMP_IOCCCPASSWD_JSON 2>$TMP_STDERR" 1>&2
    fi
    "$SCP_PASSWD_SH" "$TMP_IOCCCPASSWD_JSON" 2>"$TMP_STDERR"
    status="$?"
    if [[ $status -ne 0 ]]; then
	git_exit 1 "$0: ERROR: again: $SCP_PASSWD_SH $TMP_IOCCCPASSWD_JSON 2>$TMP_STDERR failed, error: $status"
    fi
    replace_file_git_add "$TMP_IOCCCPASSWD_JSON" "$IOCCCPASSWD_JSON"
    rm -f "$TMP_IOCCCPASSWD_JSON" # temp file no longer needed
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not re-update iocccpasswd.json file: $IOCCCPASSWD_JSON" 1>&2
fi


# re-form temporary iocccpasswd.lst file
#
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 3 ]]; then
	echo  "$0: debug[3]: again: temporary iocccpasswd.lst file: $TMP_IOCCCPASSWD_LST" 1>&2
    fi
    trap 'rm -f $LOCK $TMP_STDERR $TMP_GIT_COMMIT $TMP_IOCCCPASSWD_LST; exit' 0 1 2 3 15
    rm -f "$TMP_IOCCCPASSWD_LST"
    if [[ -e $TMP_IOCCCPASSWD_LST ]]; then
	git_exit 1 "$0: ERROR: cannot re-remove iocccpasswd.lst file: $TMP_IOCCCPASSWD_LST"
    fi
    : >  "$TMP_IOCCCPASSWD_LST"
    if [[ ! -e $TMP_IOCCCPASSWD_LST ]]; then
	git_exit 1 "$0: ERROR: cannot re-create iocccpasswd.lst file: $TMP_IOCCCPASSWD_LST"
    fi
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not re-form temporary iocccpasswd.lst file: $TMP_IOCCCPASSWD_LST" 1>&2
fi


# update iocccpasswd.lst again
#
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: again: $SCP_PASSWD_SH $TMP_IOCCCPASSWD_LST 2>$TMP_STDERR" 1>&2
    fi
    "$SSH_EMAIL_PR_SH" "$TMP_IOCCCPASSWD_LST" 2>"$TMP_STDERR"
    status="$?"
    if [[ $status -ne 0 ]]; then
	git_exit 1 "$0: ERROR: again: $SCP_PASSWD_SH $TMP_IOCCCPASSWD_LST 2>$TMP_STDERR failed, error: $status"
    fi
    replace_file_git_add "$TMP_IOCCCPASSWD_LST" "$IOCCCPASSWD_LST"
    rm -f "$TMP_IOCCCPASSWD_LST" # temp file no longer needed
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not re-update iocccpasswd.lst file: $IOCCCPASSWD_LST" 1>&2
fi


# verify that all email new addresses collected from the beginning of this job accounts
#
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: if $COMM_EMAIL_SH $REGISTER_LST $IOCCCPASSWD_LST 2>$TMP_STDERR ..." 1>&2
    fi
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: again: $COMM_EMAIL_SH $REGISTER_LST $IOCCCPASSWD_LST $TMP_RUN_LST 2>>$TMP_STDERR" 1>&2
    fi
    "$COMM_EMAIL_SH" "$REGISTER_LST" "$IOCCCPASSWD_LST" "$TMP_RUN_LST" 2>>"$TMP_STDERR"
    status="$?"
    if [[ $status -ne 0 ]]; then
	git_exit 1 "$0: ERROR: $COMM_EMAIL_SH $REGISTER_LST $IOCCCPASSWD_LST $TMP_RUN_LST 2>>$TMP_STDERR failed, error: $status"
    fi

    # case: Some email addresses were NOT properly processed
    #
    if [[ -s $TMP_RUN_LST ]]; then
	{
	    echo
	    echo "$0: ERROR: Some email addresses were NOT properly processed"
	    echo
	    echo "$0: Notice: email addresses NOT properly processed starts below"
	    cat "$TMP_RUN_LST"
	    echo "$0: Notice: email addresses NOT properly processed ends above"
	} >> "$TMP_GIT_COMMIT"
	git_exit 1 "$0: ERROR: files differ: register.lst: $REGISTER_LST iocccpasswd.lst: $IOCCCPASSWD_LST"

    # case: all addresses were processed
    #
    else
	{
	    echo
	    echo "All new email addresses successfully processed"
	} >> "$TMP_GIT_COMMIT"
    fi

elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not compare: $REGISTER_LST and: $IOCCCPASSWD_LST" 1>&2
fi


# commit the changes if needed
#
GIT_COMMIT_NEEDED="true"
if [[ -z $NOOP ]]; then
    if [[ -n $USE_GIT && -n $GIT_COMMIT_NEEDED && -n $TMP_GIT_COMMIT && -s $TMP_GIT_COMMIT ]]; then
	git_commit "$TMP_GIT_COMMIT"
	status="$?"
	if [[ $status -ne 0 ]]; then
	    git_exit 1 "$0: ERROR: again: git_commit $TMP_GIT_COMMIT failed, error: $status"
	fi
    fi
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not again: git_commit $$TMP_GIT_COMMIT" 1>&2
fi


# if using git, display the re-commit message
#
if [[ $V_FLAG -ge 1 && -s $TMP_GIT_COMMIT ]]; then
    echo "$0: debug[1]: git re-commit message starts below" 1>&2
    cat "$TMP_GIT_COMMIT" 1>&2
    echo "$0: debug[1]: git re-commit message ends above" 1>&2
fi


# if using git, push any commits
#
if [[ -z $NOOP ]]; then
    if [[ -n $USE_GIT ]]; then
	git_push .
	status="$?"
	if [[ $status -ne 0 ]]; then
	    git_exit 1 "$0: ERROR: again: git_push . failed, error: $status"
	fi
    fi
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not again: git_push ." 1>&2
fi


# All Done!!! All Done!!! -- Jessica Noll, Age 2
#
exit 0
