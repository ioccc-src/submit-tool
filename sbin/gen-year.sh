#!/usr/bin/env bash
#
# gen-year.sh - generate an IOCCC year containing all submissions
#
# Given an IOCCC working directory containing a "submit" tree with
# "USERNAME-SLOT_NUM" subdirectories (USERSLOT), we generate copies of each
# USERSLOT under a new YYYY directory (given as an arg top this command).
#
# Each "submit.number" will contain a copy of the current state of each
# given USERSLOT under "submit".  The original USERSLOT subdirectory under
# "submit" remains as an untouched reference throughout the judging.
#
# Each "submit.number" copy is nearly identical to the original USERSLOT
# with the following exceptions:
#
#   The ".prev" symlink, if one existed in the original,
#   will point to the previous timestamp of # the submission.
#
#   The ".txz" symlink will point to the compressed tarball
#   under original USERSLOT.
#
#   A new ".orig" symlink will point to the original USERSLOT.
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


# other required bash options
#
# Requires bash with a version 4.2 or later
#
shopt -s lastpipe	# run last command of a pipeline not executed in the background in the current shell environment


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
export VERSION="2.1.2 2025-06-30"
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
export USE_GIT="true"
export WORKDIR="/usr/ioccc/ioccc-work"
export EXIT_CODE=0
#
export TMPDIR
if [[ -z $TMPDIR ]]; then
    TMPDIR="/tmp"
fi
#
export DESTSHARE="/usr/local/share/submit-tool"
export MAKEFILE_YEAR="$DESTSHARE/Makefile.year"
export VAR_MK="$DESTSHARE/var.mk"
export LEET_MK="$DESTSHARE/1337.mk"
export CLANG_FORMAT="$DESTSHARE/.clang-format"
export MAKEFILE_JUDGING="$DESTSHARE/Makefile.judging"
export TRY_SH_JUDGING="$DESTSHARE/try.sh.judging"


# rsync options we use to copy
#
unset RSYNC_OPTIONS
declare -ag RSYNC_OPTIONS
RSYNC_OPTIONS+=("--from0")
RSYNC_OPTIONS+=("--force")
RSYNC_OPTIONS+=("--group")
RSYNC_OPTIONS+=("--links")
RSYNC_OPTIONS+=("--no-motd")
RSYNC_OPTIONS+=("--owner")
RSYNC_OPTIONS+=("--perms")
RSYNC_OPTIONS+=("--recursive")
RSYNC_OPTIONS+=("--sparse")
RSYNC_OPTIONS+=("--times")
RSYNC_OPTIONS+=("--whole-file")
RSYNC_OPTIONS+=("--one-file-system")
unset RSYNC_VERBOSE_OPTIONS
declare -ag RSYNC_VERBOSE_OPTIONS
RSYNC_VERBOSE_OPTIONS+=("--stats")
RSYNC_VERBOSE_OPTIONS+=("--verbose")


# usage
#
export USAGE="usage: $0 [-h] [-v level] [-V] [-n] [-N] [-i ioccc.rc] [-I]
	[-2 sha256_tool] [-R rsync_tool] [-w workdir] YYYY

    -h              print help message and exit
    -v level        set verbosity level (def level: 0)
    -V              print version string and exit

    -n              go thru the actions, but do not update except temporary files (def: do the action)
    -N              do not process anything, just parse arguments (def: process something)

    -i ioccc.rc     Use ioccc.rc as the rc startup file (def: $IOCCC_RC)
    -I              Do not use any rc startup file (def: do)

    -2 sha256_tool  use local sha256_tool to hash (def: $SHA256_TOOL)
    -R rsync_tool   use local rsync tool to sync trees (def: $RSYNC_TOOL)

    -w workdir      cd to the workdir before running (def: stay in $WORKDIR)

    YYYY            year directory to form under workdir

Exit codes:
     0        all OK
     1        failed to form YYYY or a submit.number sub-directory
     2        -h and help string printed or -V and version string printed
     3        command line error
     4        source of ioccc.rc file failed
     5        some critical local executable tool or file not found
     6	      invalid USERSLOT subdirectory under submit found
     7	      workdir invalid or missing mandatory sub-directory
 >= 10        internal error

$NAME version: $VERSION"


# parse command line
#
while getopts :hv:VnNi:I:2:R:w: flag; do
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
    2) SHA256_TOOL="$OPTARG"
	;;
    R) RSYNC_TOOL="$OPTARG"
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
if [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: file argument count: $#" 1>&2
fi
if [[ $# -ne 1 ]]; then
    echo "$0: ERROR: expected 1 arg, found: $#" 1>&2
    exit 3
fi
export YYYY="$1"


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
    # We need to source the .ioccc.rc file
    #
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
    echo "$0: debug[3]: IOCCC_RC=$IOCCC_RC" 1>&2
    echo "$0: debug[3]: CAP_I_FLAG=$CAP_I_FLAG" 1>&2
    echo "$0: debug[3]: SHA256_TOOL=$SHA256_TOOL" 1>&2
    echo "$0: debug[3]: RSYNC_TOOL=$RSYNC_TOOL" 1>&2
    echo "$0: debug[3]: WORKDIR=$WORKDIR" 1>&2
    echo "$0: debug[3]: EXIT_CODE=$EXIT_CODE" 1>&2
    echo "$0: debug[3]: TMPDIR=$TMPDIR" 1>&2
    echo "$0: debug[3]: RSYNC_OPTIONS=${RSYNC_OPTIONS[*]}" 1>&2
    echo "$0: debug[3]: RSYNC_VERBOSE_OPTIONS=${RSYNC_VERBOSE_OPTIONS[*]}" 1>&2
    echo "$0: debug[3]: YYYY=$YYYY" 1>&2
    echo "$0: debug[3]: DESTSHARE=$DESTSHARE" 1>&2
    echo "$0: debug[3]: MAKEFILE_YEAR=$MAKEFILE_YEAR" 1>&2
    echo "$0: debug[3]: VAR_MK=$VAR_MK" 1>&2
    echo "$0: debug[3]: LEET_MK=$LEET_MK" 1>&2
    echo "$0: debug[3]: CLANG_FORMAT=$CLANG_FORMAT" 1>&2
    echo "$0: debug[3]: MAKEFILE_JUDGING=$MAKEFILE_JUDGING" 1>&2
    echo "$0: debug[3]: TRY_SH_JUDGING=$TRY_SH_JUDGING" 1>&2
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


# find the Makefile.year file
#
if [[ ! -s $MAKEFILE_YEAR ]]; then
    echo "$0: ERROR: cannot find non-empty Makefile.year file: $MAKEFILE_YEAR" 1>&2
    exit 5
fi


# find the var.mk file
#
if [[ ! -s $VAR_MK ]]; then
    echo "$0: ERROR: cannot find non-empty var.mk file: $VAR_MK" 1>&2
    exit 5
fi


# find the 1337.mk file
#
if [[ ! -s $LEET_MK ]]; then
    echo "$0: ERROR: cannot find non-empty 1337.mk file: $LEET_MK" 1>&2
    exit 5
fi


# find the .clang-format file
#
if [[ ! -s $CLANG_FORMAT ]]; then
    echo "$0: ERROR: cannot find non-empty .clang-format file: $CLANG_FORMAT" 1>&2
    exit 5
fi


# find the Makefile.judging file
#
if [[ ! -s $MAKEFILE_JUDGING ]]; then
    echo "$0: ERROR: cannot find non-empty Makefile.judging file: $MAKEFILE_JUDGING" 1>&2
    exit 5
fi


# find the try.sh.judging file
#
if [[ ! -s $TRY_SH_JUDGING ]]; then
    echo "$0: ERROR: cannot find non-empty try.sh.judging file: $TRY_SH_JUDGING" 1>&2
    exit 5
fi


# move to WORKDIR if WORKDIR is not .
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


# firewall - YYYY must not exist
#
if [[ -e $YYYY ]]; then
    echo "$0: ERROR: YYYY already exists: $YYYY" 1>&2
    exit 1
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


# update var.mk under WORKDIR if needed
#
if ! cmp -s "$VAR_MK" "$WORKDIR/var.mk" 2>/dev/null; then

    if [[ $V_FLAG -ge 3 ]]; then
	echo "$0: debug[3]: about to cp -p -f $VAR_MK $WORKDIR/var.mk" 1>&2
    fi
    if [[ -z $NOOP ]]; then
	cp -p -f "$VAR_MK" "$WORKDIR/var.mk" 2>/dev/null
	status="$?"
	if [[ $status -ne 0 || ! -s $WORKDIR/var.mk ]]; then
	    echo "$0: ERROR: cp -p -f $VAR_MK $WORKDIR/var.mk failed, error: $status" 1>&2
	    exit 7
	fi
    elif [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: because of -n, did not cp -p -f $VAR_MK $WORKDIR/var.mk" 1>&2
    fi

elif [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: var.mk is up to date: $WORKDIR/var.mk" 1>&2
fi


# update 1337.mk under WORKDIR if needed
#
if ! cmp -s "$LEET_MK" "$WORKDIR/1337.mk" 2>/dev/null; then

    if [[ $V_FLAG -ge 3 ]]; then
	echo "$0: debug[3]: about to cp -p -f $LEET_MK $WORKDIR/1337.mk" 1>&2
    fi
    if [[ -z $NOOP ]]; then
	cp -p -f "$LEET_MK" "$WORKDIR/1337.mk" 2>/dev/null
	status="$?"
	if [[ $status -ne 0 || ! -s $WORKDIR/1337.mk ]]; then
	    echo "$0: ERROR: cp -p -f $LEET_MK $WORKDIR/1337.mk failed, error: $status" 1>&2
	    exit 7
	fi
    elif [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: because of -n, did not cp -p -f $LEET_MK $WORKDIR/1337.mk" 1>&2
    fi

elif [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: 1337.mk is up to date: $WORKDIR/1337.mk" 1>&2
fi


# update .clang-format under WORKDIR if needed
#
if ! cmp -s "$CLANG_FORMAT" "$WORKDIR/.clang-format" 2>/dev/null; then

    if [[ $V_FLAG -ge 3 ]]; then
	echo "$0: debug[3]: about to cp -p -f $CLANG_FORMAT $WORKDIR/.clang-format" 1>&2
    fi
    if [[ -z $NOOP ]]; then
	cp -p -f "$CLANG_FORMAT" "$WORKDIR/.clang-format" 2>/dev/null
	status="$?"
	if [[ $status -ne 0 || ! -s $WORKDIR/.clang-format ]]; then
	    echo "$0: ERROR: cp -p -f $CLANG_FORMAT $WORKDIR/.clang-format failed, error: $status" 1>&2
	    exit 7
	fi
    elif [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: because of -n, did not cp -p -f $CLANG_FORMAT $WORKDIR/.clang-format" 1>&2
    fi

elif [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: .clang-format is up to date: $WORKDIR/.clang-format" 1>&2
fi


# create a temporary exit code
#
# It is a pain to set the EXIT_CODE deep inside a loop, so we write the EXIT_CODE into a file
# and read the file (setting EXIT_CODE again) after the loop.  A hack, but good enough for our needs.
#
export TMP_EXIT_CODE="$TMPDIR/.tmp.$NAME.EXIT_CODE.$$.tmp"
if [[ $V_FLAG -ge 3 ]]; then
    echo  "$0: debug[3]: temporary exit code: $TMP_EXIT_CODE" 1>&2
fi
# In this case we always create TMP_EXIT_CODE even if -n, because of the complex shell loops below
trap 'rm -f $TMP_EXIT_CODE; exit' 0 1 2 3 15
rm -f "$TMP_EXIT_CODE"
if [[ -e $TMP_EXIT_CODE ]]; then
    echo "$0: ERROR: cannot remove temporary exit code: $TMP_EXIT_CODE" 1>&2
    exit 11
fi
echo "$EXIT_CODE" > "$TMP_EXIT_CODE"
if [[ ! -e $TMP_EXIT_CODE ]]; then
    echo "$0: ERROR: cannot create temporary exit code: $TMP_EXIT_CODE" 1>&2
    exit 12
fi


# build a sorted array of USER_SLOT directories
#
# We sort by the SHA256 hash of the USER_SLOT/current/.submit.sh file
# so that the "submit.number" sub-directories we create under YYYY
# will not be in any apparent order.
#
unset USER_SLOT
declare -ag USER_SLOT			# USERSLOT paths from WORKDIR sorted by SHA256 hash of .submit.sh contents
unset TIMESTAMP_DOT_NUM
declare -ag TIMESTAMP_DOT_NUM		# timestamp[.num] sorted by SHA256 hash of .submit.sh contents
unset PREV_TIMESTAMP_DOT_NUM
declare -ag PREV_TIMESTAMP_DOT_NUM	# .prev timestamp[.num] sorted by SHA256 hash of .submit.sh contents
unset TXZ_FILENAME
declare -ag TXZ_FILENAME		# .txz filename sorted by SHA256 hash of .submit.sh contents
#
find submit -mindepth 1 -maxdepth 1 -type d -name '[0-9a-f]*[0-9]' 2>/dev/null |
    grep -E '^submit/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}-[0-9]+$' |
    while read -r USER_SLOT_PATH; do

    # USER_SLOT_PATH must have a current symlink to a directory
    #
    export CURRENT="$USER_SLOT_PATH/current"
    if [[ ! -L $CURRENT ]]; then
	echo "$0: ERROR: current is not a symlink under USER_SLOT_PATH: $USER_SLOT_PATH" 1>&2
	echo 6 > "$TMP_EXIT_CODE" # exit 6
	continue
    fi
    if [[ ! -d $CURRENT ]]; then
	echo "$0: ERROR: current does not point to a directory under USER_SLOT_PATH: $USER_SLOT_PATH" 1>&2
	echo 6 > "$TMP_EXIT_CODE" # exit 6
	continue
    fi

    # current symlink to a directory must have a readable .submit.sh file
    #
    export SUBMIT_SH="$CURRENT/.submit.sh"
    if [[ ! -e $SUBMIT_SH ]]; then
	echo "$0: ERROR: no .submit.sh found under current: $CURRENT" 1>&2
	echo 6 > "$TMP_EXIT_CODE" # exit 6
	continue
    fi
    if [[ ! -f $SUBMIT_SH ]]; then
	echo "$0: ERROR: .submit.sh is not a file under current: $CURRENT" 1>&2
	echo 6 > "$TMP_EXIT_CODE" # exit 6
	continue
    fi
    if [[ ! -r $SUBMIT_SH ]]; then
	echo "$0: ERROR: .submit.sh is not a readable file under current: $CURRENT" 1>&2
	echo 6 > "$TMP_EXIT_CODE" # exit 6
	continue
    fi

    # determine the SHA256 hash of the .submit.sh file under current
    #
    if [[ $V_FLAG -ge 9 ]]; then
	echo "$0: debug[9]: about to: $SHA256_TOOL -b $SUBMIT_SH" 1>&2
    fi
    export HEXDIGEST
    HEXDIGEST=$("$SHA256_TOOL" -b "$SUBMIT_SH" 2>/dev/null)
    status="$?"
    if [[ $status -ne 0 || -z $HEXDIGEST ]]; then
	echo "$0: ERROR: $SHA256_TOOL -b $SUBMIT_SH failed, error: $status" 1>&2
	echo 6 > "$TMP_EXIT_CODE" # exit 6
	continue
    fi
    HEXDIGEST=${HEXDIGEST%% *}
    if [[ $V_FLAG -ge 7 ]]; then
	echo "$0: debug[7]: SHA256 hash of $SUBMIT_SH: $HEXDIGEST" 1>&2
    fi
    if [[ -z $HEXDIGEST ]]; then
	echo "$0: ERROR: failed to determine SHA256 of .submit.sh: $SUBMIT_SH" 1>&2
	echo 6 > "$TMP_EXIT_CODE" # exit 6
	continue
    fi

    # output SHA256 hash of .submit.sh and USER_SLOT path
    #
    echo "$HEXDIGEST $USER_SLOT_PATH"

# sort by SHA256 hash of .submit.sh file contents
#
done | sort -d | while read -r SORTED_HEXDIGEST SORTED_USER_SLOT_PATH; do

    # SORTED_USER_SLOT_PATH must have a current symlink to a directory
    #
    export SORTED_CURRENT="$SORTED_USER_SLOT_PATH/current"
    if [[ ! -L $SORTED_CURRENT ]]; then
	echo "$0: ERROR: current is not a symlink under SORTED_USER_SLOT_PATH: $SORTED_USER_SLOT_PATH" 1>&2
	echo 6 > "$TMP_EXIT_CODE" # exit 6
	continue
    fi
    if [[ ! -d $SORTED_CURRENT ]]; then
	echo "$0: ERROR: current does not point to a directory under SORTED_USER_SLOT_PATH: $SORTED_USER_SLOT_PATH" 1>&2
	echo 6 > "$TMP_EXIT_CODE" # exit 6
	continue
    fi

    # current symlink to a directory must have a readable .submit.sh file
    #
    export SORTED_SUBMIT_SH="$SORTED_CURRENT/.submit.sh"
    if [[ ! -e $SORTED_SUBMIT_SH ]]; then
	echo "$0: ERROR: no .submit.sh found under current: $SORTED_CURRENT" 1>&2
	echo 6 > "$TMP_EXIT_CODE" # exit 6
	continue
    fi
    if [[ ! -f $SORTED_SUBMIT_SH ]]; then
	echo "$0: ERROR: .submit.sh is not a file under current: $SORTED_CURRENT" 1>&2
	echo 6 > "$TMP_EXIT_CODE" # exit 6
	continue
    fi
    if [[ ! -r $SORTED_SUBMIT_SH ]]; then
	echo "$0: ERROR: .submit.sh is not a readable file under current: $SORTED_CURRENT" 1>&2
	echo 6 > "$TMP_EXIT_CODE" # exit 6
	continue
    fi

    # clear any previous values source in .submit.sh files
    #
    export DOT_NUM=""
    export IOCCC_USERNAME=""
    export PREV=""
    export SLOT_NUM=""
    export SUBMIT_DATETIME=""
    export SUBMIT_TIMESTAMP=""
    export SUBMIT_TIMESTAMP_DOT_NUM=""
    export TXZ_FILENAME_DOT_NUM=""
    export TXZ_SHA256=""
    export USERSLOT=""

    # source .submit.sh into this shell
    #
    # SC1090 (warning): ShellCheck can't follow non-constant source. Use a directive to specify location.
    # https://www.shellcheck.net/wiki/SC1090
    # shellcheck disable=SC1090
    source "$SORTED_SUBMIT_SH"
    status="$?"
    if [[ $status -ne 0 ]]; then
        echo "$0: ERROR: source $SORTED_SUBMIT_SH error code: $status" 1>&2
	echo 6 > "$TMP_EXIT_CODE" # exit 6
	continue
    fi

    # verify .submit.sh values are non-empty, except for perhaps DOT_NUM and PREV
    #
    if [[ -z $IOCCC_USERNAME ]]; then
	echo "$0: ERROR: .submit.sh IOCCC_USERNAME is empty in .submit.sh: $SORTED_SUBMIT_SH" 1>&2
	echo 6 > "$TMP_EXIT_CODE" # exit 6
	continue
    fi
    if [[ -z $SLOT_NUM ]]; then
	echo "$0: ERROR: .submit.sh SLOT_NUM is empty in .submit.sh: $SORTED_SUBMIT_SH" 1>&2
	echo 6 > "$TMP_EXIT_CODE" # exit 6
	continue
    fi
    if [[ -z $SUBMIT_DATETIME ]]; then
	echo "$0: ERROR: .submit.sh SUBMIT_DATETIME is empty in .submit.sh: $SORTED_SUBMIT_SH" 1>&2
	echo 6 > "$TMP_EXIT_CODE" # exit 6
	continue
    fi
    if [[ -z $SUBMIT_TIMESTAMP ]]; then
	echo "$0: ERROR: .submit.sh SUBMIT_TIMESTAMP is empty in .submit.sh: $SORTED_SUBMIT_SH" 1>&2
	echo 6 > "$TMP_EXIT_CODE" # exit 6
	continue
    fi
    if [[ -z $SUBMIT_TIMESTAMP_DOT_NUM ]]; then
	echo "$0: ERROR: .submit.sh SUBMIT_TIMESTAMP_DOT_NUM is empty in .submit.sh: $SORTED_SUBMIT_SH" 1>&2
	echo 6 > "$TMP_EXIT_CODE" # exit 6
	continue
    fi
    if [[ -z $TXZ_FILENAME_DOT_NUM ]]; then
	echo "$0: ERROR: .submit.sh TXZ_FILENAME_DOT_NUM is empty in .submit.sh: $SORTED_SUBMIT_SH" 1>&2
	echo 6 > "$TMP_EXIT_CODE" # exit 6
	continue
    fi
    if [[ -z $USERSLOT ]]; then
	echo "$0: ERROR: .submit.sh USERSLOT is empty in .submit.sh: $SORTED_SUBMIT_SH" 1>&2
	echo 6 > "$TMP_EXIT_CODE" # exit 6
	continue
    fi

    # verify if DOT_NUM is empty or not based on if the file .num.sh exists or not
    #
    export NUM_SH="$SORTED_CURRENT/.num.sh"
    #
    # case: we have a .num.sh file
    #
    if [[ -f $NUM_SH ]]; then
	if [[ -z $DOT_NUM ]]; then
	    echo "$0: ERROR: .num.sh exists: $NUM_SH however" \
		 ".submit.sh DOT_NUM is empty in .submit.sh: $SORTED_SUBMIT_SH" 1>&2
	    echo 6 > "$TMP_EXIT_CODE" # exit 6
	    continue
	fi
    else
	if [[ -n $DOT_NUM ]]; then
	    echo "$0: ERROR: .num.sh does not exist: $NUM_SH however" \
		 ".submit.sh DOT_NUM is not empty in .submit.sh: $SORTED_SUBMIT_SH" 1>&2
	    echo 6 > "$TMP_EXIT_CODE" # exit 6
	    continue
	fi
    fi

    # verify if PREV is empty or not based on if the .prev symlink exists or not
    #
    export DOT_PREV="$SORTED_CURRENT/.prev"
    #
    # case: we have a .prev symlink
    #
    if [[ -L $DOT_PREV ]]; then

	# verify PREV is not empty
	#
	if [[ -z $PREV ]]; then
	    echo "$0: ERROR: .prev exists: $PREV however" \
		 ".submit.sh PREV is empty in .submit.sh: $SORTED_SUBMIT_SH" 1>&2
	    echo 6 > "$TMP_EXIT_CODE" # exit 6
	    continue
	fi

	# verify that submit/$USERSLOT/$PREV matches what the .prev symlink points at
	#
	export PREV_PATH="submit/$USERSLOT/$PREV"
	if [[ ! $PREV_PATH -ef $DOT_PREV ]]; then
	    echo "$0: ERROR: PREV_PATH: $PREV_PATH != SORTED_CURRENT/.prev: $DOT_PREV" 1>&2
	    echo 6 > "$TMP_EXIT_CODE" # exit 6
	    continue
	fi

    # case: we do NOT have a .prev symlink
    #
    else

	# verify PREV is empty
	#
	if [[ -n $PREV ]]; then
	    echo "$0: ERROR: .prev does not exist: $PREV however" \
		 ".submit.sh PREV is not empty: $PREV in .submit.sh: $SORTED_SUBMIT_SH" 1>&2
	    echo 6 > "$TMP_EXIT_CODE" # exit 6
	    continue
	fi
    fi

    # verify that submit/$USERSLOT matches $SORTED_USER_SLOT_PATH
    #
    export SUBMIT_USERSLOT="submit/$USERSLOT"
    if [[ $SUBMIT_USERSLOT != "$SORTED_USER_SLOT_PATH" ]]; then
	echo "$0: ERROR: SUBMIT_USERSLOT: $SUBMIT_USERSLOT != SORTED_USER_SLOT_PATH: $SORTED_USER_SLOT_PATH" 1>&2
	echo 6 > "$TMP_EXIT_CODE" # exit 6
	continue
    fi

    # verify that submit/$USERSLOT/txz/$TXZ_FILENAME_DOT_NUM matches what the .txz symlink points at
    #
    export TXZ_PATH="submit/$USERSLOT/txz/$TXZ_FILENAME_DOT_NUM"
    if [[ ! $TXZ_PATH -ef $SORTED_CURRENT/.txz ]]; then
	echo "$0: ERROR: TXZ_PATH: $TXZ_PATH is not the same file as .txz: $SORTED_CURRENT/.txz" 1>&2
	echo 6 > "$TMP_EXIT_CODE" # exit 6
	continue
    fi

    # validate args read
    #
    if [[ -z $SORTED_HEXDIGEST ]]; then
	echo "$0: ERROR: empty SHA256 SORTED_HEXDIGEST found for USER_SLOT: $SORTED_USER_SLOT_PATH" 1>&2
	echo 6 > "$TMP_EXIT_CODE" # exit 6
	continue
    fi
    if [[ -z $SORTED_USER_SLOT_PATH ]]; then
	echo "$0: ERROR: empty USER_SLOT path for USER_SLOT: $SORTED_USER_SLOT_PATH" 1>&2
	echo 6 > "$TMP_EXIT_CODE" # exit 6
	continue
    fi

    # append this sorted USERSLOT information
    #
    TIMESTAMP_DOT_NUM+=("$SUBMIT_TIMESTAMP_DOT_NUM")
    PREV_TIMESTAMP_DOT_NUM+=("$PREV")
    TXZ_FILENAME+=("$TXZ_FILENAME_DOT_NUM")
    USER_SLOT+=("$SORTED_USER_SLOT_PATH")
done
#
# paranoia - validate array lengths
#
if [[ ${#USER_SLOT[*]} -ne ${#TIMESTAMP_DOT_NUM[*]} ]]; then
    echo "$0: ERROR: USER_SLOT array length: ${#USER_SLOT[*]} != " \
	 "TIMESTAMP_DOT_NUM array length: ${#TIMESTAMP_DOT_NUM[*]}" 1>&2
    echo 6 > "$TMP_EXIT_CODE" # exit 6
    # continue on anyway and abort later
fi
if [[ ${#USER_SLOT[*]} -ne ${#PREV_TIMESTAMP_DOT_NUM[*]} ]]; then
    echo "$0: ERROR: USER_SLOT array length: ${#USER_SLOT[*]} != " \
	 "PREV_TIMESTAMP_DOT_NUM array length: ${#PREV_TIMESTAMP_DOT_NUM[*]}" 1>&2
    echo 6 > "$TMP_EXIT_CODE" # exit 6
    # continue on anyway and abort later
fi
if [[ ${#USER_SLOT[*]} -ne ${#TXZ_FILENAME[*]} ]]; then
    echo "$0: ERROR: USER_SLOT array length: ${#USER_SLOT[*]} != " \
	 "TXZ_FILENAME array length: ${#TXZ_FILENAME[*]}" 1>&2
    echo 6 > "$TMP_EXIT_CODE" # exit 6
    # continue on anyway and abort later
fi
#
if [[ $V_FLAG -ge 5 ]]; then
    for index in "${!USER_SLOT[@]}"; do
	 echo "$0: debug[5]: TIMESTAMP_DOT_NUM[$index]=${TIMESTAMP_DOT_NUM[$index]}" 1>&2
	 echo "$0: debug[5]: PREV_TIMESTAMP_DOT_NUM[$index]=${PREV_TIMESTAMP_DOT_NUM[$index]}" 1>&2
	 echo "$0: debug[5]: TXZ_FILENAME[$index]=${TXZ_FILENAME[$index]}" 1>&2
	 echo "$0: debug[5]: USER_SLOT[$index]=${USER_SLOT[$index]}" 1>&2
    done
fi
if [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: TIMESTAMP_DOT_NUM array length: ${#TIMESTAMP_DOT_NUM[*]}" 1>&2
    echo "$0: debug[3]: PREV_TIMESTAMP_DOT_NUM array length: ${#PREV_TIMESTAMP_DOT_NUM[*]}" 1>&2
    echo "$0: debug[3]: TXZ_FILENAME array length: ${#TXZ_FILENAME[*]}" 1>&2
    echo "$0: debug[3]: USER_SLOT array length: ${#USER_SLOT[*]}" 1>&2
fi


# firewall - exit early if the above sorting loops failed
#
EXIT_CODE=$(< "$TMP_EXIT_CODE")
if [[ -z $EXIT_CODE ]]; then
    echo "$0: ERROR: temporary exit file is empty: $TMP_EXIT_CODE" 1>&2
    exit 13
fi
if [[ $EXIT_CODE -ne 0 ]]; then
    echo "$0: Warning: about to exit $EXIT_CODE" 1>&2
    exit "$EXIT_CODE"
fi


# determine the format of the submit.number sub-directories under YYYY
#
export USER_SLOT_LENGTH="${#USER_SLOT[*]}"
export USER_SLOT_DIGITS="${#USER_SLOT_LENGTH}"
export PRINTF_NUMBER_FORMAT="%0${USER_SLOT_DIGITS}d"
if [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[3]: USER_SLOT_LENGTH=$USER_SLOT_LENGTH" 1>&2
    echo "$0: debug[3]: USER_SLOT_DIGITS=$USER_SLOT_DIGITS" 1>&2
    echo "$0: debug[3]: PRINTF_NUMBER_FORMAT=$PRINTF_NUMBER_FORMAT" 1>&2
fi


# form the YYYY directory
#
if [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: about to: mkdir -p $YYYY" 1>&2
fi
if [[ -z $NOOP ]]; then
    mkdir -p "$YYYY"
    status="$?"
    if [[ $status -ne 0 || ! -d $YYYY ]]; then
	echo "$0: ERROR: mkdir -p $YYYY failed, error: $status" 1>&2
	exit 1
    fi
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not form YYYY directory: $YYYY" 1>&2
fi


# copy all current SLOTDIR under YYYY, renaming them as submit.number
#
unset SUBMIT_NUMBER
declare -ag SUBMIT_NUMBER		# submit.number subdirectory under YYYY
for index in "${!USER_SLOT[@]}"; do

    # determine the rsync from path
    #
    export FROM_PATH="${USER_SLOT[$index]}/${TIMESTAMP_DOT_NUM[$index]}"
    if [[ ! -d $FROM_PATH ]]; then
	echo "$0: ERROR: FROM_PATH[$index] is not a directory: $FROM_PATH" 1>&2
	echo 1 > "$TMP_EXIT_CODE" # exit 1
	continue
    fi
    if [[ $V_FLAG -ge 5 ]]; then
	echo "$0: debug[5]: FROM_PATH: $FROM_PATH" 1>&2
    fi

    # determine the rsync to path
    #
    # We have a pattern variable
    #
    # SC2059 (info): Don't use variables in the printf format string. Use printf '..%s..' "$foo".
    # https://www.shellcheck.net/wiki/SC2059
    # shellcheck disable=SC2059
    printf -v SUBMIT_NAME "submit.$PRINTF_NUMBER_FORMAT" "$index"
    SUBMIT_NUMBER+=("$SUBMIT_NAME")
    export TO_PATH="$YYYY/$SUBMIT_NAME"
    if [[ $V_FLAG -ge 5 ]]; then
	echo "$0: debug[5]: TO_PATH: $TO_PATH" 1>&2
    fi

    # copy SLOTDIR to submit.number
    #
    if [[ -z $NOOP ]]; then

	if [[ $V_FLAG -ge 5 ]]; then
	    echo "$0: debug[5]: about to: $RSYNC_TOOL ${RSYNC_OPTIONS[*]}" \
		 "${RSYNC_VERBOSE_OPTIONS[*]} $FROM_PATH/ $TO_PATH" 1>&2
	fi
	if [[ $V_FLAG -ge 5 ]]; then
	    "$RSYNC_TOOL" "${RSYNC_OPTIONS[@]}" "${RSYNC_VERBOSE_OPTIONS[@]}" "$FROM_PATH/" "$TO_PATH"
	    status="$?"
	    if [[ $status -ne 0 ]]; then
		echo "$0: ERROR: $RSYNC_TOOL ${RSYNC_OPTIONS[*]} ${RSYNC_VERBOSE_OPTIONS[*]}" \
		     "$FROM_PATH/ $TO_PATH failed, error: $status" 1>&2
		echo 1 > "$TMP_EXIT_CODE" # exit 1
		continue
	    fi
	else
	    "$RSYNC_TOOL" "${RSYNC_OPTIONS[@]}" "$FROM_PATH/" "$TO_PATH"
	    status="$?"
	    if [[ $status -ne 0 ]]; then
		echo "$0: ERROR: $RSYNC_TOOL ${RSYNC_OPTIONS[*]}" \
		     "$FROM_PATH/ $TO_PATH failed, error: $status" 1>&2
		echo 1 > "$TMP_EXIT_CODE" # exit 1
		continue
	    fi
	fi
	if [[ $V_FLAG -ge 3 ]]; then
	    echo "$0: debug[3]: copied $FROM_PATH/ to $TO_PATH" 1>&2
	fi

    elif [[ $V_FLAG -ge 5 ]]; then
	echo "$0: debug[5]: because of -n, did not copy $FROM_PATH/ to $TO_PATH" 1>&2
    fi

    # chmod 0444 files under submit.number
    #
    if [[ -z $NOOP ]]; then

	if [[ $V_FLAG -ge 5 ]]; then
	    echo "$0: debug[5]: about to: find $TO_PATH -type f -print0 2>/dev/null | xargs -0 chmod 0444 -v" 1>&2
	fi
	if [[ $V_FLAG -ge 5 ]]; then
	    find "$TO_PATH" -type f -print0 2>/dev/null | xargs -0 chmod 0444 -v
	    status_codes=("${PIPESTATUS[@]}")
	    if [[ ${status_codes[*]} =~ [1-9] ]]; then
		echo "$0: find $TO_PATH -type f -print0 2>/dev/null | xargs -0 chmod 0444 -v" \
		     "error codes: ${status_codes[*]}" 1>&2
		echo 1 > "$TMP_EXIT_CODE" # exit 1
		continue
	    fi
	else
	    find "$TO_PATH" -type f -print0 2>/dev/null | xargs -0 chmod 0444
	    status_codes=("${PIPESTATUS[@]}")
	    if [[ ${status_codes[*]} =~ [1-9] ]]; then
		echo "$0: find $TO_PATH -type f -print0 2>/dev/null | xargs -0 chmod 0444" \
		     "error codes: ${status_codes[*]}" 1>&2
		echo 1 > "$TMP_EXIT_CODE" # exit 1
		continue
	    fi
	fi

    elif [[ $V_FLAG -ge 5 ]]; then
	echo "$0: debug[5]: because of -n, did not chmod 0444 files under: $TO_PATH" 1>&2
    fi

    # chmod 0555 if we have try.sh
    #
    if [[ -f $TO_PATH/try.sh ]]; then

	if [[ -z $NOOP ]]; then

	    if [[ $V_FLAG -ge 5 ]]; then
		echo "$0: debug[5]: about to: chmod 0555 -v $TO_PATH/try.sh" 1>&2
	    fi
	    if [[ $V_FLAG -ge 5 ]]; then
		chmod 0555 -v "$TO_PATH/try.sh"
		status="$?"
		if [[ $status -ne 0 ]]; then
		    echo "$0: ERROR: chmod 0555 -v $TO_PATH/try.sh failed, error: $status" 1>&2
		    echo 1 > "$TMP_EXIT_CODE" # exit 1
		    continue
		fi
	    else
		chmod 0555 "$TO_PATH/try.sh"
		status="$?"
		if [[ $status -ne 0 ]]; then
		    echo "$0: ERROR: chmod 0555 $TO_PATH/try.sh failed, error: $status" 1>&2
		    echo 1 > "$TMP_EXIT_CODE" # exit 1
		    continue
		fi
	    fi

	elif [[ $V_FLAG -ge 5 ]]; then
	    echo "$0: debug[5]: because of -n, did not chmod 0555 files under: $TO_PATH" 1>&2
	fi
    fi

    # chmod 0555 if we have try.alt.sh
    #
    if [[ -f $TO_PATH/try.alt.sh ]]; then

	if [[ -z $NOOP ]]; then

	    if [[ $V_FLAG -ge 5 ]]; then
		echo "$0: debug[5]: about to: chmod 0555 -v $TO_PATH/try.alt.sh" 1>&2
	    fi
	    if [[ $V_FLAG -ge 5 ]]; then
		chmod 0555 -v "$TO_PATH/try.alt.sh"
		status="$?"
		if [[ $status -ne 0 ]]; then
		    echo "$0: ERROR: chmod 0555 -v $TO_PATH/try.alt.sh failed, error: $status" 1>&2
		    echo 1 > "$TMP_EXIT_CODE" # exit 1
		    continue
		fi
	    else
		chmod 0555 "$TO_PATH/try.alt.sh"
		status="$?"
		if [[ $status -ne 0 ]]; then
		    echo "$0: ERROR: chmod 0555 $TO_PATH/try.alt.sh failed, error: $status" 1>&2
		    echo 1 > "$TMP_EXIT_CODE" # exit 1
		    continue
		fi
	    fi

	elif [[ $V_FLAG -ge 5 ]]; then
	    echo "$0: debug[5]: because of -n, did not chmod 0555 files under: $TO_PATH" 1>&2
	fi
    fi

    # if we copied a .prev symlink, change the .prev symlink to point at the submit tree
    #
    export DOT_PREV="$TO_PATH/.prev"
    export SUBMIT_PREV_PATH="../../${USER_SLOT[$index]}/${PREV_TIMESTAMP_DOT_NUM[$index]}"
    if [[ -L $DOT_PREV ]]; then

	# pre-remove .prev
	#
	if [[ -z $NOOP ]]; then

	    if [[ $V_FLAG -ge 5 ]]; then
		echo "$0: debug[5]: about to: rm -f $DOT_PREV" 1>&2
	    fi
	    rm -f "$DOT_PREV"
	    status="$?"
	    if [[ $status -ne 0 ]]; then
		echo "$0: ERROR: rm -f $DOT_PREV failed, error: $status" 1>&2
		echo 1 > "$TMP_EXIT_CODE" # exit 1
		continue
	    fi

	elif [[ $V_FLAG -ge 5 ]]; then
	    echo "$0: debug[5]: because of -n, did not pre-remove .prev: $DOT_PREV" 1>&2
	fi

	# form new .prev
	#
	if [[ -z $NOOP ]]; then

	    if [[ $V_FLAG -ge 5 ]]; then
		echo "$0: debug[5]: about to: ln -s $SUBMIT_PREV_PATH $DOT_PREV" 1>&2
	    fi
	    ln -s "$SUBMIT_PREV_PATH" "$DOT_PREV"
	    status="$?"
	    if [[ $status -ne 0 ]]; then
		echo "$0: ERROR: ln -s $SUBMIT_PREV_PATH $DOT_PREV failed, error: $status" 1>&2
		echo 1 > "$TMP_EXIT_CODE" # exit 1
		continue
	    fi

	elif [[ $V_FLAG -ge 5 ]]; then
	    echo "$0: debug[5]: because of -n, did not reform: .prev as: $SUBMIT_PREV_PATH" 1>&2
	fi
    fi

    # form .orig symlink to point at the original USERSLOT timestamp directory
    #
    export DOT_ORIG="$TO_PATH/.orig"
    export SUBMIT_TIMESTAMP_PATH="../../${USER_SLOT[$index]}/${TIMESTAMP_DOT_NUM[$index]}"
    if [[ -z $NOOP ]]; then

	# pre-remove .orig
	#
	if [[ -z $NOOP ]]; then

	    if [[ $V_FLAG -ge 5 ]]; then
		echo "$0: debug[5]: about to: rm -f $DOT_ORIG" 1>&2
	    fi
	    rm -f "$DOT_ORIG"
	    status="$?"
	    if [[ $status -ne 0 ]]; then
		echo "$0: ERROR: rm -f $DOT_ORIG failed, error: $status" 1>&2
		echo 1 > "$TMP_EXIT_CODE" # exit 1
		continue
	    fi

	elif [[ $V_FLAG -ge 5 ]]; then
	    echo "$0: debug[5]: because of -n, did not pre-remove .orig: $DOT_ORIG" 1>&2
	fi

	# form new .orig
	#
	if [[ -z $NOOP ]]; then

	    if [[ $V_FLAG -ge 5 ]]; then
		echo "$0: debug[5]: about to: ln -s $SUBMIT_TIMESTAMP_PATH $DOT_ORIG" 1>&2
	    fi
	    ln -s "$SUBMIT_TIMESTAMP_PATH" "$DOT_ORIG"
	    status="$?"
	    if [[ $status -ne 0 ]]; then
		echo "$0: ERROR: ln -s $SUBMIT_TIMESTAMP_PATH $DOT_ORIG failed, error: $status" 1>&2
		echo 1 > "$TMP_EXIT_CODE" # exit 1
		continue
	    fi

	elif [[ $V_FLAG -ge 5 ]]; then
	    echo "$0: debug[5]: because of -n, did not reform: .orig as: $SUBMIT_TIMESTAMP_PATH" 1>&2
	fi

    elif [[ $V_FLAG -ge 5 ]]; then
	echo "$0: debug[5]: because of -n, did not form: .orig as: $SUBMIT_TIMESTAMP_PATH" 1>&2
    fi

    # fix .txz to point at the original compressed tarball file
    #
    export DOT_TXZ="$TO_PATH/.txz"
    export SUBMIT_TXZ_PATH="../../${USER_SLOT[$index]}/txz/${TXZ_FILENAME[$index]}"
    if [[ -z $NOOP ]]; then

	# pre-remove .orig
	#
	if [[ -z $NOOP ]]; then

	    if [[ $V_FLAG -ge 5 ]]; then
		echo "$0: debug[5]: about to: rm -f $DOT_TXZ" 1>&2
	    fi
	    rm -f "$DOT_TXZ"
	    status="$?"
	    if [[ $status -ne 0 ]]; then
		echo "$0: ERROR: rm -f $DOT_TXZ failed, error: $status" 1>&2
		echo 1 > "$TMP_EXIT_CODE" # exit 1
		continue
	    fi

	elif [[ $V_FLAG -ge 5 ]]; then
	    echo "$0: debug[5]: because of -n, did not pre-remove .txz: $DOT_TXZ" 1>&2
	fi

	# form new .txz
	#
	if [[ -z $NOOP ]]; then

	    if [[ $V_FLAG -ge 5 ]]; then
		echo "$0: debug[5]: about to: ln -s $SUBMIT_TXZ_PATH $DOT_TXZ" 1>&2
	    fi
	    ln -s "$SUBMIT_TXZ_PATH" "$DOT_TXZ"
	    status="$?"
	    if [[ $status -ne 0 ]]; then
		echo "$0: ERROR: ln -s $SUBMIT_TXZ_PATH $DOT_TXZ failed, error: $status" 1>&2
		echo 1 > "$TMP_EXIT_CODE" # exit 1
		continue
	    fi

	elif [[ $V_FLAG -ge 5 ]]; then
	    echo "$0: debug[5]: because of -n, did not reform: .txz as: $SUBMIT_TXZ_PATH" 1>&2
	fi
    elif [[ $V_FLAG -ge 5 ]]; then
	echo "$0: debug[5]: because of -n, did not form: .txz as: $SUBMIT_TXZ_PATH" 1>&2
    fi

    # report on this submit.number
    #
    if [[ -z $NOOP ]]; then
	if [[ $V_FLAG -ge 1 ]]; then
	    echo "$0: debug[1]: setup $TO_PATH" 1>&2
	fi
    elif [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: because of -n, did not form: setup $TO_PATH" 1>&2
    fi
done


# form the Makefile under YYYY
#
export YYYY_MAKEFILE="$YYYY/Makefile"
if [[ -z $NOOP ]]; then

    # pre-remove Makefile under YYYY
    #
    if [[ -z $NOOP ]]; then

	if [[ $V_FLAG -ge 5 ]]; then
	    echo "$0: debug[5]: about to: rm -f $YYYY_MAKEFILE" 1>&2
	fi
	rm -f "$YYYY_MAKEFILE"
	status="$?"
	if [[ $status -ne 0 ]]; then
	    echo "$0: ERROR: rm -f $YYYY_MAKEFILE failed, error: $status" 1>&2
	    exit 1
	fi

    elif [[ $V_FLAG -ge 5 ]]; then
	echo "$0: debug[5]: because of -n, did not pre-remove $YYYY_MAKEFILE" 1>&2
    fi

    # setup YEAR from Makefile.year template
    #
    sed -e "s/%%YEAR%%/$YYYY/g" "$MAKEFILE_YEAR" > "$YYYY_MAKEFILE"
    status="$?"
    if [[ $status -ne 0 || ! -s $YYYY_MAKEFILE ]]; then
	echo "$0: ERROR: sed -e s/%%YEAR%%/$YYYY/g $MAKEFILE_YEAR > $YYYY_MAKEFILE failed, error: $status" 1>&2
	exit 7
    fi

elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not form: $YYYY_MAKEFILE" 1>&2
fi


# update Makefile.judging under YYYY if needed
#
if ! cmp -s "$MAKEFILE_JUDGING" "$YYYY/Makefile.judging" 2>/dev/null; then

    if [[ $V_FLAG -ge 3 ]]; then
	echo "$0: debug[3]: about to cp -p -f $MAKEFILE_JUDGING $YYYY/Makefile.judging" 1>&2
    fi
    if [[ -z $NOOP ]]; then
	cp -p -f "$MAKEFILE_JUDGING" "$YYYY/Makefile.judging" 2>/dev/null
	status="$?"
	if [[ $status -ne 0 || ! -s $YYYY/Makefile.judging ]]; then
	    echo "$0: ERROR: cp -p -f $MAKEFILE_JUDGING $YYYY/Makefile.judging failed, error: $status" 1>&2
	    exit 7
	fi
    elif [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: because of -n, did not cp -p -f $MAKEFILE_JUDGING $YYYY/Makefile.judging" 1>&2
    fi

elif [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: Makefile.judging is up to date: $YYYY/Makefile.judging" 1>&2
fi


# update try.sh.judging under YYYY if needed
#
if ! cmp -s "$TRY_SH_JUDGING" "$YYYY/try.sh.judging" 2>/dev/null; then

    if [[ $V_FLAG -ge 3 ]]; then
	echo "$0: debug[3]: about to cp -p -f $TRY_SH_JUDGING $YYYY/try.sh.judging" 1>&2
    fi
    if [[ -z $NOOP ]]; then
	cp -p -f "$TRY_SH_JUDGING" "$YYYY/try.sh.judging" 2>/dev/null
	status="$?"
	if [[ $status -ne 0 || ! -s $YYYY/try.sh.judging ]]; then
	    echo "$0: ERROR: cp -p -f $TRY_SH_JUDGING $YYYY/try.sh.judging failed, error: $status" 1>&2
	    exit 7
	fi
    elif [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: because of -n, did not cp -p -f $TRY_SH_JUDGING $YYYY/try.sh.judging" 1>&2
    fi

elif [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: try.sh.judging is up to date: $YYYY/try.sh.judging" 1>&2
fi


# All Done!!! All Done!!! -- Jessica Noll, Age 2
#
# firewall - exit if the above submit.number loops failed
EXIT_CODE=$(< "$TMP_EXIT_CODE")
if [[ -z $EXIT_CODE ]]; then
    echo "$0: ERROR: temporary exit file is empty: $TMP_EXIT_CODE" 1>&2
    exit 14
fi
if [[ $EXIT_CODE -ne 0 ]]; then
    echo "$0: Warning: about to exit $EXIT_CODE" 1>&2
    exit "$EXIT_CODE"
fi
rm -f "$TMP_EXIT_CODE"
exit 0
