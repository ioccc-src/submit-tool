#!/usr/bin/env bash
#
# run.sh - run command under a given user
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
export VERSION="2.0.2 2025-02-22"
NAME=$(basename "$0")
export NAME
export V_FLAG=0
#
export DO_NOT_PROCESS=
#
export SUBMIT_RC="$HOME/.submit.rc"
#
export SUDO_CMD
if [[ -z $SUDO_CMD ]]; then
    SUDO_CMD=$(type -P sudo)
    if [[ -z $SUDO_CMD ]]; then
	echo "$0: ERROR: sudo command not in \$PATH" 1>&2
	exit 6
    fi
fi
#
export SUDO_USER


# usage
#
export USAGE="usage: $0 [-h] [-v level] [-V] [-N] [-i submit.rc] [-I] [-u user] cmd [args ..]

	-h		print help message and exit
	-v level	set verbosity level (def level: 0)
	-V		print version string and exit

	-N		do not process anything, just parse arguments (def: process something)

	-i submit.rc	Use submit.rc as the rc startup file (def: $SUBMIT_RC)
	-I		Do not use any rc startup file (def: do)

	-u user		use sudo to run the command (def: do not use sudo)

	cmd		command to run
	[args ..]	args to supply to the cmd

Exit codes:
     0         all OK
     1         cmd exited non-zero
     2         -h and help string printed or -V and version string printed
     3         command line error
     4         source of submit.rc file failed
     5         cmd not found or not exeutable
     6	       sudo not found

 >= 10        internal error

$NAME version: $VERSION"


# parse command line
#
while getopts :hv:VNi:Iu: flag; do
  case "$flag" in
    h) echo "$USAGE" 1>&2
	exit 2
	;;
    v) V_FLAG="$OPTARG"
	;;
    V) echo "$VERSION"
	exit 2
	;;
    N) DO_NOT_PROCESS="-N"
	;;
    i) SUBMIT_RC="$OPTARG"
	;;
    I) CAP_I_FLAG="true"
	;;
    u) SUDO_USER="$OPTARG"
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
if [[ $# -le 0 ]]; then
    echo "$0: ERROR: expected 1 args, found: $#" 1>&2
    exit 3
fi
CMD="$1"
shift 1


# unless -I, verify the submit.rc file, if it exists
#
if [[ -z $CAP_I_FLAG ]]; then
    # if we do not have a readable submit.rc file, remove the SUBMIT_RC value
    if [[ ! -r $SUBMIT_RC ]]; then
	SUBMIT_RC=""
    fi
else
    # -I used, remove the SUBMIT_RC value
    SUBMIT_RC=""
fi


# If we still have an SUBMIT_RC value, source it
#
if [[ -n $SUBMIT_RC ]]; then
    export status=0
    if [[ $V_FLAG -ge 3 ]]; then
	echo "$0: debug[3]: about to source $SUBMIT_RC" 1>&2
    fi
    # SC1090 (warning): ShellCheck can't follow non-constant source. Use a directive to specify location.
    # https://www.shellcheck.net/wiki/SC1090
    # shellcheck disable=SC1090
    source "$SUBMIT_RC"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: source $SUBMIT_RC failed, error: $status" 1>&2
	exit 4
    fi
fi


# firewall - CMD must be executable
#
if [[ ! -x $CMD ]]; then

    # search for the command on the path
    CMD_ON_PATH=$(type -P "$CMD")
    if [[ -z $CMD_ON_PATH ]]; then
	echo "$0: ERROR: cmd not executable: $CMD" 1>&2
	exit 5
    else
	CMD="$CMD_ON_PATH"
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
    echo "$0: debug[3]: DO_NOT_PROCESS=$DO_NOT_PROCESS" 1>&2
    echo "$0: debug[3]: SUBMIT_RC=$SUBMIT_RC" 1>&2
    echo "$0: debug[3]: CMD=$CMD" 1>&2
    echo "$0: debug[3]: args=$*" 1>&2
    echo "$0: debug[3]: SUDO_CMD=$SUDO_CMD" 1>&2
    echo "$0: debug[3]: SUDO_USER=$SUDO_USER" 1>&2
fi


# case: run without sudo
#
if [[ -z $SUDO_USER ]]; then

    if [[ $V_FLAG -ge 1 ]]; then
        echo "$0: debug[3]: about to run: $CMD $*" 1>&2
    fi
    "$CMD" "$@"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: $CMD $* failed, error: $status" 1>&2
        exit 1
    fi

else

    if [[ $V_FLAG -ge 1 ]]; then
        echo "$0: debug[3]: about to run: $SUDO_CMD -u $SUDO_USER $CMD $*" 1>&2
    fi
    "$SUDO_CMD" -u "$SUDO_USER" "$CMD" "$@"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: $SUDO_CMD -u $SUDO_USER $CMD $* failed, error: $status" 1>&2
        exit 1
    fi

fi


# All Done!!! All Done!!! -- Jessica Noll, Age 2
#
exit 0
