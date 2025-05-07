#!/usr/bin/env bash
#
# post-collect.sh - actions on a collected submission directory
#
# After `sbin/collect.sh` obtains a new submission, performs checks via
#	`txzchk(1)` and `chkentry(1)` we need to compress the `.auth.json`
#	file and to setup several symlnks.  The former is to help avoid
#	accidental authorship disclose during the judging process and
#	the later is to help navigate among the various uploads
#	and compressed tarballs of a submission.
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
export VERSION="2.0.0 2025-05-06"
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
export XZ_TOOL
if [[ -z $XZ_TOOL ]]; then
    XZ_TOOL=$(type -P xz)
    if [[ -z "$XZ_TOOL" ]]; then
	echo "$0: FATAL: xz tool is not installed or not in \$PATH" 1>&2
	exit 5
    fi
fi
#
export JPARSE_TOOL
if [[ -z $JPARSE_TOOL ]]; then
    JPARSE_TOOL=$(type -P jparse)
fi
#
export JVAL_TOOL
if [[ -z $JVAL_TOOL ]]; then
    JVAL_TOOL=$(type -P jval.sh)
fi
export J_FLAG="0"
#
export SHA256_TOOL
if [[ -z $SHA256_TOOL ]]; then
    SHA256_TOOL=$(type -P sha256sum)
fi
export GIVEN_HEXDIGEST=""


# usage
#
export USAGE="usage: $0 [-h] [-v level] [-V] [-n] [-N] [-i ioccc.rc] [-I]
        [-j jpase] [-t jval.sh] [-2 sha256_tool] [-x xz] [-H hexdigest] slot_path

        -h              print help message and exit
        -v level        set verbosity level (def level: 0)
        -V              print version string and exit

        -n              go thru the actions, but do not update any files (def: do the action)
        -N              do not process anything, just parse arguments (def: process something)

        -i ioccc.rc     Use ioccc.rc as the rc startup file (def: $IOCCC_RC)
        -I              Do not use any rc startup file (def: do)

        -j jparse       path to the jparse tool (def: $JPARSE_TOOL)
        -J level        set JSON verbosity level (def $J_FLAG)

        -t jval.sh      use local jval.sh tool (def: $JVAL_TOOL)
        -2 sha256_tool  use local sha256_tool to hash (def: $SHA256_TOOL)
        -x xz           use local xz tool to compress (def: $XZ_TOOL)

	-H hexdigest	SHA256 hash of compressed tarball (def: compute using sha256_tool)

        slot_path       slot directory to process

Exit codes:
     0        all OK
     1        some internal tool is missing or exited non-zero
     2        -h and help string printed or -V and version string printed
     3        command line error
     4        source of ioccc.rc file failed
     5        some critical local executable tool not found
     6        .info.json file is invalid or not readable or missing
     7        .num.sh exists but source of .num.sh failed
     8        compressed tarball not found
 >= 10        internal error

$NAME version: $VERSION"


# parse command line
#
while getopts :hv:VnNi:Ij:J:t:2:x:H: flag; do
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
    j) JPARSE_TOOL="$OPTARG"
	;;
    J) J_FLAG="$OPTARG"
	;;
    t) JVAL_TOOL="$OPTARG"
	;;
    2) SHA256_TOOL="$OPTARG"
	;;
    x) XZ_TOOL="$OPTARG"
	;;
    H) GIVEN_HEXDIGEST="$OPTARG"
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
export SLOT_PATH="$1"


# firewall - slot path must be a writable directory
#
if [[ ! -d $SLOT_PATH ]]; then
    echo "$0: ERROR: workdir is not a directory: $SLOT_PATH" 1>&2
    exit 7
fi
if [[ ! -w $SLOT_PATH ]]; then
    echo "$0: ERROR: workdir is not a writable directory: $SLOT_PATH" 1>&2
    exit 7
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


# firewall - XZ_TOOL must be executable
#
if [[ ! -x $XZ_TOOL ]]; then
    echo "$0: ERROR: xz tool not executable: $XZ_TOOL" 1>&2
    exit 5
fi


# firewall - JPARSE_TOOL must be executable
#
if [[ -z "$JPARSE_TOOL" || ! -x $JPARSE_TOOL ]]; then
    echo "$0: FATAL: jparse tool is not installed or not in \$PATH" 1>&2
    echo "$0: notice: to install jparse:" 1>&2
    echo "$0: notice: run: git clone https://github.com/ioccc-src/mkiocccentry.git" 1>&2
    echo "$0: notice: then: cd mkiocccentry && make clobber all" 1>&2
    echo "$0: notice: then: cd jparse && sudo make install clobber" 1>&2
    exit 5
fi


# firewall - JVAL_TOOL must be executable
#
if [[ -z "$JVAL_TOOL" || ! -x $JVAL_TOOL ]]; then
    echo "$0: FATAL: jval.sh tool is not installed or not in \$PATH" 1>&2
    exit 5
fi


# firewall - SHA256_TOOL must be executable
#
if [[ -z "$SHA256_TOOL" || ! -x $SHA256_TOOL ]]; then
    echo "$0: FATAL: sha256sum tool is not installed or not in \$PATH" 1>&2
    exit 5
fi


# must have a readable .info.json file
#
export INFO_JSON="$SLOT_PATH/.info.json"
if [[ ! -e $INFO_JSON ]]; then
    echo "$0: ERROR: info.json file does not exist: $INFO_JSON" 1>&2
    exit 6
fi
if [[ ! -f $INFO_JSON ]]; then
    echo "$0: ERROR: info.json is not a file: $INFO_JSON" 1>&2
    exit 6
fi
if [[ ! -r $INFO_JSON ]]; then
    echo "$0: ERROR: info.json is not a readable file: $INFO_JSON" 1>&2
    exit 6
fi


# .info.json file must be valid JSON
#
if [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: about to: $JPARSE_TOOL -q -J $J_FLAG -- $INFO_JSON" 1>&2
fi
"$JPARSE_TOOL" -q -J "$J_FLAG" -- "$INFO_JSON"
status="$?"
if [[ $status -ne 0 ]]; then
    echo "$0: ERROR: $JPARSE_TOOL -q -J $J_FLAG -- $INFO_JSON failed, error: $status" 1>&2
    exit 6
fi


# obtain the IOCCC contest ID
#
if [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: about to: $JVAL_TOOL -q $INFO_JSON 'IOCCC_contest_id'" 1>&2
fi
export IOCCC_USERNAME
IOCCC_USERNAME=$("$JVAL_TOOL" -q "$INFO_JSON" 'IOCCC_contest_id')
status="$?"
if [[ $status -ne 0 ]]; then
    echo "$0: ERROR: $JVAL_TOOL -q $INFO_JSON 'IOCCC_contest_id' failed, error: $status" 1>&2
    exit 6
fi
if [[ -z $IOCCC_USERNAME ]]; then
    echo "$0: ERROR: unable to obtain IOCCC_contest_id from: $INFO_JSON" 1>&2
    exit 6
fi


# obtain the compressed tarball filename
#
if [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: about to: $JVAL_TOOL -q $INFO_JSON 'tarball'" 1>&2
fi
export TARBALL
TARBALL=$("$JVAL_TOOL" -q "$INFO_JSON" 'tarball')
status="$?"
if [[ $status -ne 0 ]]; then
    echo "$0: ERROR: $JVAL_TOOL -q $INFO_JSON 'tarball' failed, error: $status" 1>&2
    exit 6
fi
if [[ -z $TARBALL ]]; then
    echo "$0: ERROR: unable to obtain tarball from: $INFO_JSON" 1>&2
    exit 6
fi


# obtain the formed timestamp
#
if [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: about to: $JVAL_TOOL -q $INFO_JSON 'formed_timestamp'" 1>&2
fi
export TIMESTAMP
TIMESTAMP=$("$JVAL_TOOL" -q "$INFO_JSON" 'formed_timestamp')
status="$?"
if [[ $status -ne 0 ]]; then
    echo "$0: ERROR: $JVAL_TOOL -q $INFO_JSON 'formed_timestamp' failed, error: $status" 1>&2
    exit 6
fi
if [[ -z $TIMESTAMP ]]; then
    echo "$0: ERROR: unable to obtain formed_timestamp from: $INFO_JSON" 1>&2
    exit 6
fi
export TIMESTAMP_DOT_NUM="$TIMESTAMP"
DATETIME=$(LANG=C date -u -d "@$TIMESTAMP")
export DATETIME


# obtain the submission slot number
#
if [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: about to: $JVAL_TOOL -q $INFO_JSON 'submit_slot'" 1>&2
fi
export SLOT_NUM
SLOT_NUM=$("$JVAL_TOOL" -q "$INFO_JSON" 'submit_slot')
status="$?"
if [[ $status -ne 0 ]]; then
    echo "$0: ERROR: $JVAL_TOOL -q $INFO_JSON 'submit_slot' failed, error: $status" 1>&2
    exit 6
fi
if [[ -z $SLOT_NUM ]]; then
    echo "$0: ERROR: unable to obtain submit_slot from: $INFO_JSON" 1>&2
    exit 6
fi
export USERSLOT="$IOCCC_USERNAME-$SLOT_NUM"


# if we have .num.sh, source the file
#
export DOT_NUM=""
export NUM_SH="$SLOT_PATH/.num.sh"
if [[ -r $NUM_SH ]]; then
    # This next source should set DOT_NUM
    #
    # SC1090 (warning): ShellCheck can't follow non-constant source. Use a directive to specify location.
    # https://www.shellcheck.net/wiki/SC1090
    # shellcheck disable=SC1090
    source "$NUM_SH"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: source .num.sh failed, error: $status" 1>&2
	exit 7
    fi
else
    # no readable .num.sh file, clear NUM_SH
    NUM_SH=""
fi


# if we have a DOT_NUM value, modify TIMESTAMP_DOT_NUM and TARBALL
#
if [[ -n $DOT_NUM ]]; then
    TIMESTAMP_DOT_NUM="$TIMESTAMP.$DOT_NUM"
    TARBALL="${TARBALL%%.txz}.$DOT_NUM.txz"
fi
export TARBALL_PATH="../txz/$TARBALL"


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
    echo "$0: debug[3]: XZ_TOOL=$XZ_TOOL" 1>&2
    echo "$0: debug[3]: JPARSE_TOOL=$JPARSE_TOOL" 1>&2
    echo "$0: debug[3]: J_FLAG=$J_FLAG" 1>&2
    echo "$0: debug[3]: JVAL_TOOL=$JVAL_TOOL" 1>&2
    echo "$0: debug[3]: SHA256_TOOL=$SHA256_TOOL" 1>&2
    echo "$0: debug[3]: GIVEN_HEXDIGEST=$GIVEN_HEXDIGEST" 1>&2
    echo "$0: debug[3]: SLOT_PATH=$SLOT_PATH" 1>&2
    echo "$0: debug[3]: IOCCC_USERNAME=$IOCCC_USERNAME" 1>&2
    echo "$0: debug[3]: TARBALL=$TARBALL" 1>&2
    echo "$0: debug[3]: TARBALL_PATH=$TARBALL_PATH" 1>&2
    echo "$0: debug[3]: TIMESTAMP=$TIMESTAMP" 1>&2
    echo "$0: debug[3]: TIMESTAMP_DOT_NUM=$TIMESTAMP_DOT_NUM" 1>&2
    echo "$0: debug[3]: DATETIME=$DATETIME" 1>&2
    echo "$0: debug[3]: SLOT_NUM=$SLOT_NUM" 1>&2
    echo "$0: debug[3]: USERSLOT=$USERSLOT" 1>&2
    echo "$0: debug[3]: DOT_NUM=$DOT_NUM" 1>&2
    if [[ -n $NUM_SH ]]; then
	echo "$0: debug[3]: NUM_SH=$NUM_SH" 1>&2
	echo "$0: Warning: .num.sh output starts below"
	cat "$NUM_SH"
	echo "$0: Warning: .num.sh output ends above"
    fi
fi


# -N stops early before any processing is performed
#
if [[ -n $DO_NOT_PROCESS ]]; then
    if [[ $V_FLAG -ge 3 ]]; then
	echo "$0: debug[3]: arguments parsed, -N given, exiting 0" 1>&2
    fi
    exit 0
fi


# move to slot path if slot path is not .
#
if [[ $SLOT_PATH != "." ]]; then
    if [[ $V_FLAG -ge 3 ]]; then
	echo "$0: debug[3]: about to cd $SLOT_PATH" 1>&2
    fi
    export CD_FAILED=""
    cd "$SLOT_PATH" || CD_FAILED="true"
    if [[ -n $CD_FAILED ]]; then
	echo "$0: ERROR: cd $SLOT_PATH failed" 1>&2
	exit 7
    fi
fi
if [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: current working directory is: $(/bin/pwd)" 1>&2
fi


# sanity check - tarball must exist
#
if [[ ! -e $TARBALL_PATH ]]; then
    echo "$0: ERROR: compressed tarball does not exit: $TARBALL_PATH" 1>&2
    exit 8
fi
if [[ ! -f $TARBALL_PATH ]]; then
    echo "$0: ERROR: compressed tarball not a file: $TARBALL_PATH" 1>&2
    exit 8
fi
if [[ ! -f $TARBALL_PATH ]]; then
    echo "$0: ERROR: compressed tarball not readable: $TARBALL_PATH" 1>&2
    exit 8
fi


# form temporary stderr collection file
#
export TMP_STDERR=".tmp.$NAME.STDERR.$$.tmp"
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 3 ]]; then
	echo  "$0: debug[3]: temporary stderr collection file: $TMP_STDERR" 1>&2
    fi
    trap 'rm -f $TMP_STDERR; exit' 0 1 2 3 15
    rm -f "$TMP_STDERR"
    if [[ -e $TMP_STDERR ]]; then
	echo "$0: ERROR: cannot remove stderr collection file: $TMP_STDERR" 1>&2
	exit 10
    fi
    : >  "$TMP_STDERR"
    if [[ ! -e $TMP_STDERR ]]; then
	echo "$0: ERROR: cannot create stderr collection file: $TMP_STDERR" 1>&2
	exit 11
    fi
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not form temporary stderr collection file: $TMP_STDERR" 1>&2
fi


# compute SHA256 hash of the compressed tarball
#
if [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: about to: $SHA256_TOOL -b $TARBALL_PATH" 1>&2
fi
export HEXDIGEST
HEXDIGEST=$("$SHA256_TOOL" -b "$TARBALL_PATH" 2>"$TMP_STDERR")
status="$?"
if [[ $status -ne 0 || -z $HEXDIGEST ]]; then
    echo "$0: ERROR: $SHA256_TOOL -b $TARBALL_PATH failed, error: $status" 1>&2
    echo "$0: ERROR: stderr output starts below" 1>&2
    cat "$TMP_STDERR" 1>&2
    echo "$0: ERROR: stderr output ends above" 1>&2
    exit 12
fi
HEXDIGEST=${HEXDIGEST%% *}
if [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: about to: sha256 hash of $TARBALL_PATH: $HEXDIGEST" 1>&2
fi
if [[ -n $GIVEN_HEXDIGEST && $GIVEN_HEXDIGEST != "$HEXDIGEST" ]]; then
    echo "$0: ERROR: sha256 hash of  $TARBALL_PATH: $HEXDIGEST != -H $GIVEN_HEXDIGEST" 1>&2
    exit 13
fi


# as an "gram of protection", compress the .auth.json file if .auth.json.xz is not found
#
export AUTH_JSON=".auth.json"
export AUTH_JSON_XZ="$AUTH_JSON.xz"
if [[ -z $NOOP ]]; then

    if [[ -s $AUTH_JSON && ! -s $AUTH_JSON_XZ ]]; then

	if [[ $V_FLAG -ge 1 ]]; then
	    echo "$0: debug[1]: about to: $XZ_TOOL -z -f $AUTH_JSON 2>$TMP_STDERR" 1>&2
	fi
	"$XZ_TOOL" -z -f "$AUTH_JSON" 2>"$TMP_STDERR"
	status="$?"
	if [[ $status -ne 0 ]]; then

	    # just report cannot compress .auth.json file
	    #
	    echo "$0: ERROR: $XZ_TOOL -z -f $AUTH_JSON 2>$TMP_STDERR failed, error: $status" 1>&2
	    echo "$0: ERROR: stderr output starts below" 1>&2
	    cat "$TMP_STDERR" 1>&2
	    echo "$0: ERROR: stderr output ends above" 1>&2
	    exit 14
	fi
    fi

    if [[ -f $AUTH_JSON ]]; then
	if [[ -s $AUTH_JSON ]]; then
	    echo "$0: ERROR: non-empty .auth.json still found: $AUTH_JSON" 1>&2
	else
	    echo "$0: ERROR: empty .auth.json still found: $AUTH_JSON" 1>&2
	fi
	exit 15
    fi

    if [[ ! -f $AUTH_JSON_XZ ]]; then
	if [[ -s $AUTH_JSON_XZ ]]; then
	    echo "$0: ERROR: non-empty .auth.json.xz found: $AUTH_JSON_XZ" 1>&2
	else
	    echo "$0: ERROR: empty .auth.json.xz found: $AUTH_JSON_XZ" 1>&2
	fi
	exit 16
    fi

elif [[ $V_FLAG -ge 1 ]]; then
     echo "$0: debug[1]: because of -n, did not compress: $AUTH_JSON into $AUTH_JSON_XZ " 1>&2
fi


# form .txz symlink to the compressed tarball
#
# firewall - .txz must NOT exist
#
if [[ -z $NOOP ]]; then

    # pre-remove .txz
    #
    if [[ -e .txz ]]; then
	if [[ $V_FLAG -ge 1 ]]; then
	    echo "$0: debug[1]: about to: rm -f .txz 2>$TMP_STDERR" 1>&2
	fi
	rm -f .txz 2>"$TMP_STDERR" 1>&2
	status="$?"
	if [[ $status -ne 0 || -e .txz ]]; then

	    # just report a failure to pre-remove .txz
	    #
	    echo "$0: ERROR: rm -f .txz failed, error: $status" 1>&2
	    echo "$0: ERROR: stderr output starts below" 1>&2
	    cat "$TMP_STDERR" 1>&2
	    echo "$0: ERROR: stderr output ends above" 1>&2
	    exit 17
	fi
    fi

    # form .txz symlink
    #
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: ln -f -s ../txz/$TARBALL .txz 2>$TMP_STDERR" 1>&2
    fi
    ln -f -s "../txz/$TARBALL" .txz 2>"$TMP_STDERR" 1>&2
    status="$?"
    if [[ $status -ne 0 ]]; then

	# just report a failure to form .txz
	#
	echo "$0: ERROR: ln -f -s ../txz/$TARBALL .txz failed, error: $status" 1>&2
	echo "$0: ERROR: stderr output starts below" 1>&2
	cat "$TMP_STDERR" 1>&2
	echo "$0: ERROR: stderr output ends above" 1>&2
	exit 18
    fi

elif [[ $V_FLAG -ge 1 ]]; then
     echo "$0: debug[1]: because of -n, did not form: .txz" 1>&2
fi


# form a .prev symlink if we have a previous submit directory
#
export PREV=""
export PREV_DIR=""
if [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: about to: ls -1tr .. 2>/dev/null | grep -E '^[0-9]+$'" 1>&2
fi
# It is easier to pipe to grep for digits
#
# SC2010 (warning): Don't use ls | grep. Use a glob or a for loop with a condition to allow non-alphanumeric filenames.
# https://www.shellcheck.net/wiki/SC2010
# shellcheck disable=SC2010
ls -1tr .. 2>/dev/null |
    grep -E '^[0-9.]+$' |
    while read -r dir; do
	if [[ $dir == "$TIMESTAMP_DOT_NUM" ]]; then
	    break
	fi
	PREV="$dir"
    done
if [[ -n $PREV ]]; then

    # case: we have a previous submit directory
    #
    PREV_DIR="../$PREV"
    if [[ ! -d $PREV_DIR ]]; then
	echo "$0: ERROR: not a previous directory: $PREV_DIR" 1>&2
	exit 19
    fi
    if [[ -z $NOOP ]]; then

	# pre-remove .prev
	#
	if [[ -e .prev ]]; then
	    if [[ $V_FLAG -ge 1 ]]; then
		echo "$0: debug[1]: about to: rm -f .prev 2>$TMP_STDERR" 1>&2
	    fi
	    rm -f .prev 2>"$TMP_STDERR" 1>&2
	    status="$?"
	    if [[ $status -ne 0 || -e .prev ]]; then

		# just report a failure to pre-remove .prev
		#
		echo "$0: ERROR: rm -f .prev failed, error: $status" 1>&2
		echo "$0: ERROR: stderr output starts below" 1>&2
		cat "$TMP_STDERR" 1>&2
		echo "$0: ERROR: stderr output ends above" 1>&2
		exit 20
	    fi
	fi

	# form .prev symlink
	#
	if [[ $V_FLAG -ge 1 ]]; then
	    echo "$0: debug[1]: about to: ln -f -s $PREV_DIR .prev 2>$TMP_STDERR" 1>&2
	fi
	ln -f -s "$PREV_DIR" .prev 2>"$TMP_STDERR" 1>&2
	status="$?"
	if [[ $status -ne 0 ]]; then

	    echo "$0: Warning: ln -f -s $PREV_DIR .prev failed, error: $status" 1>&2
	    echo "$0: Warning: stderr output starts below" 1>&2
	    cat "$TMP_STDERR" 1>&2
	    echo "$0: Warning: stderr output ends above" 1>&2
	    exit 21
	fi

    elif [[ $V_FLAG -ge 1 ]]; then
	 echo "$0: debug[1]: because of -n, did not form: .prev" 1>&2
    fi
fi


# form the .submit.sh information file
#
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: rm -f .submit.sh 2>$TMP_STDERR" 1>&2
    fi
    rm -f .submit.sh 2>"$TMP_STDERR" 1>&2
    status="$?"
    if [[ $status -ne 0 || -e .submit.sh ]]; then

	echo "$0: Warning: rm -f .submit.sh failed, error: $status" 1>&2
	echo "$0: Warning: stderr output starts below" 1>&2
	cat "$TMP_STDERR" 1>&2
	echo "$0: Warning: stderr output ends above" 1>&2
	exit 22
    fi
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to form .submit.sh" 1>&2
	if [[ $V_FLAG -ge 3 ]]; then
	    {
		echo "$0: debug[3]: DOT_NUM=$DOT_NUM"
		echo "$0: debug[3]: IOCCC_USERNAME=$IOCCC_USERNAME"
		echo "$0: debug[3]: SLOT_NUM=$SLOT_NUM"
		echo "$0: debug[3]: SUBMIT_DATETIME='$DATETIME'"
		echo "$0: debug[3]: SUBMIT_TIMESTAMP=$TIMESTAMP"
		echo "$0: debug[3]: SUBMIT_TIMESTAMP_DOT_NUM=$TIMESTAMP_DOT_NUM"
		echo "$0: debug[3]: TXZ_FILENAME_DOT_NUM=$TARBALL"
		echo "$0: debug[3]: TXZ_SHA256=$HEXDIGEST"
		echo "$0: debug[3]: USERSLOT=$USERSLOT"
	    } 1>&2
	fi
    fi
    {
	echo "#!/usr/bin/env bash"
	echo "export DOT_NUM=$DOT_NUM"
	echo "export IOCCC_USERNAME=$IOCCC_USERNAME"
	echo "export SLOT_NUM=$SLOT_NUM"
	echo "export SUBMIT_DATETIME='$DATETIME'"
	echo "export SUBMIT_TIMESTAMP=$TIMESTAMP"
	echo "export SUBMIT_TIMESTAMP_DOT_NUM=$TIMESTAMP_DOT_NUM"
	echo "export TXZ_FILENAME_DOT_NUM=$TARBALL"
	echo "export TXZ_SHA256=$HEXDIGEST"
	echo "export USERSLOT=$USERSLOT"
    } > .submit.sh
    if [[ ! -s .submit.sh ]]; then

	# just report a failure to form .submit.sh
	#
	echo "$0: Warning: forming .submit.sh failed, error: $status" 1>&2
	echo "$0: Warning: stderr output starts below" 1>&2
	cat "$TMP_STDERR" 1>&2
	echo "$0: Warning: stderr output ends above" 1>&2
	exit 23
    fi
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to: chmod 0555 .submit.sh 2>$TMP_STDERR" 1>&2
    fi
    chmod 0555 .submit.sh 2>"$TMP_STDERR"
    if [[ $status -ne 0 || ! -x .submit.sh ]]; then

	# just report a failure to make .submit.sh executable
	#
	echo "$0: Warning: chmod 0555 .submit.sh failed, error: $status" 1>&2
	echo "$0: Warning: stderr output starts below" 1>&2
	cat "$TMP_STDERR" 1>&2
	echo "$0: Warning: stderr output ends above" 1>&2
	exit 24
    fi

elif [[ $V_FLAG -ge 1 ]]; then
     echo "$0: debug[1]: because of -n, did not form: .submit.sh" 1>&2
fi


# All Done!!! All Done!!! -- Jessica Noll, Age 2
#
exit 0
