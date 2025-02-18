#!/usr/bin/env bash
#
# multi_new_user.sh - create multiple IOCCC submit server accounts and send notification Emails
#
# We will use new_user.sh to generate zero or more IOCCC submit server accounts,
# and for those accounts created, send send notification Emails
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


# setup
#
export VERSION="1.0.4 2025-02-17"
NAME=$(basename "$0")
export NAME
export V_FLAG=0
export TOPDIR="/var/ioccc"
if [[ ! -d $TOPDIR ]]; then
    # not on submit server, assume testing in .
    TOPDIR="."
fi
export TMPDIR="$TOPDIR/tmp"
GEN_ACCT_SH=$(type -P gen_acct.sh)
export GEN_ACCT_SH
if [[ -z $GEN_ACCT_SH ]]; then
    GEN_ACCT_SH="bin/gen_acct.sh"
fi
#
REG_EMAIL_SH=$(type -P reg_email.sh)
export REG_EMAIL_SH
if [[ -z $REG_EMAIL_SH ]]; then
    REG_EMAIL_SH="bin/reg_email.sh"
fi
#
NEW_USER_SH=$(type -P new_user.sh)
export NEW_USER_SH
if [[ -z $NEW_USER_SH ]]; then
    NEW_USER_SH="bin/new_user.sh"
fi
#
IOCCC_PASSWD=$(type -P ioccc_passwd.py)
export IOCCC_PASSWD
if [[ -z $IOCCC_PASSWD ]]; then
    IOCCC_PASSWD="bin/ioccc_passwd.py"
fi
#
export NOOP=
export DO_NOT_PROCESS=
export EXIT_CODE=0
export WAIT_SECS=3


# usage
#
export USAGE="usage: $0 [-h] [-v level] [-V] [-n] [-N] [-t topdir] [-T tmpdir] [-w secs]
	[-g gen_acct] [-r reg_email] [-e new_user] [-p ioccc_passwd] file

	-h		print help message and exit
	-v level	set verbosity level (def level: 0)
	-V		print version string and exit

	-n		go thru the actions, but do not update any files (def: do the action)
	-N		do not process anything, just parse arguments (def: process something)

	-t appdir	app directory path and change tmpdir to appdir/tmp (def: $TOPDIR)
	-T tmpdir	form temp files under tmpdir (def: $TMPDIR)
	-w secs		wait secs seconds between processing users (def: $WAIT_SECS)

	-g gen_acct	tool to generate a new IOCCC submit server account (def: $GEN_ACCT_SH)
	-r reg_email	tool to send a IOCCC submit server registration email (def: $REG_EMAIL_SH)
	-e new_user	tool to create account and send notification Email (def: $REG_EMAIL_SH)
	-p ioccc_passwd	tool to create accounts in the IOCCC submit server (def: $IOCCC_PASSWD)

	file		fail with a list of 0 or more email addresses, one per line

Exit codes:
     0         all OK
     1         failed to generate at least one new user
     2         -h and help string printed or -V and version string printed
     3         command line error
     4         topdir is not a directory
     5         missing internal tool
     6         file is not a readable file
 >= 10         internal error

$NAME version: $VERSION"


# parse command line
#
while getopts :hv:VnNt:T:w:g:r:e:p: flag; do
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
    t) TOPDIR="$OPTARG"
       TMPDIR="$TOPDIR/tmp"
	;;
    T) TMPDIR="$OPTARG"
	;;
    w) WAIT_SECS="$OPTARG"
	;;
    g) GEN_ACCT_SH="$OPTARG"
	;;
    r) REG_EMAIL_SH="$OPTARG"
	;;
    e) NEW_USER_SH="$OPTARG"
	;;
    p) IOCCC_PASSWD="$OPTARG"
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
export FILE="$1"
if [[ -z $FILE ]]; then
    echo "$0: ERROR: file arg is empty" 1>&2
    exit 3
fi


# print running info if verbose
#
# If -v 3 or higher, print exported variables in order that they were exported.
#
if [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: VERSION=$VERSION" 1>&2
    echo "$0: debug[3]: NAME=$NAME" 1>&2
    echo "$0: debug[3]: V_FLAG=$V_FLAG" 1>&2
    echo "$0: debug[3]: TOPDIR=$TOPDIR" 1>&2
    echo "$0: debug[3]: TMPDIR=$TMPDIR" 1>&2
    echo "$0: debug[3]: GEN_ACCT_SH=$GEN_ACCT_SH" 1>&2
    echo "$0: debug[3]: REG_EMAIL_SH=$REG_EMAIL_SH" 1>&2
    echo "$0: debug[3]: NEW_USER_SH=$NEW_USER_SH" 1>&2
    echo "$0: debug[3]: IOCCC_PASSWD=$IOCCC_PASSWD" 1>&2
    echo "$0: debug[3]: NOOP=$NOOP" 1>&2
    echo "$0: debug[3]: DO_NOT_PROCESS=$DO_NOT_PROCESS" 1>&2
    echo "$0: debug[3]: EXIT_CODE=$EXIT_CODE" 1>&2
    echo "$0: debug[3]: WAIT_SECS=$WAIT_SECS" 1>&2
    echo "$0: debug[3]: FILE=$FILE" 1>&2
fi


# move to the top of the tree
#
export CD_FAILED=""
cd "$TOPDIR" || CD_FAILED="true"
if [[ -n $CD_FAILED ]]; then
    echo "$0: ERROR: cd $TOPDIR failed" 1>&2
    exit 4
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


# gen_acct.sh must be executable
#
if [[ ! -x $GEN_ACCT_SH ]]; then
    echo "$0: ERROR: gen_acct.sh not executable: $GEN_ACCT_SH" 1>&2
    exit 5
fi


# reg_email.sh must be executable
#
if [[ ! -x $REG_EMAIL_SH ]]; then
    echo "$0: ERROR: reg_email.sh not executable: $REG_EMAIL_SH" 1>&2
    exit 5
fi


# new_user.sh must be executable
#
if [[ ! -x $NEW_USER_SH ]]; then
    echo "$0: ERROR: reg_email.sh not executable: $NEW_USER_SH" 1>&2
    exit 5
fi


# new_user.sh must be executable
#
if [[ ! -x $IOCCC_PASSWD ]]; then
    echo "$0: ERROR: ioccc_passwd.py not executable: $IOCCC_PASSWD" 1>&2
    exit 5
fi


# file must be a readable file (OK if empty)
#
if [[ ! -e $FILE ]]; then
    echo "$0: ERROR: file does not exist: $FILE" 1>&2
    exit 6
fi
if [[ ! -f $FILE ]]; then
    echo "$0: ERROR: file does not a file: $FILE" 1>&2
    exit 6
fi
if [[ ! -e $FILE ]]; then
    echo "$0: ERROR: file does not a readable file: $FILE" 1>&2
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


# create a temporary exit code
#
# It is a pain to set the EXIT_CODE deep inside a loop, so we write the EXIT_CODE into a file
# and read the file (setting EXIT_CODE again) after the loop.  A hack, but good enough for our needs.
#
export TMP_EXIT_CODE="$TMPDIR/.tmp.$NAME.EXIT_CODE.$$.tmp"
if [[ $V_FLAG -ge 3 ]]; then
    echo  "$0: debug[3]: temporary exit code: $TMP_EXIT_CODE" 1>&2
fi
if [[ -z $NOOP ]]; then
    trap 'rm -f $TMP_EXIT_CODE; exit' 0 1 2 3 15
    rm -f "$TMP_EXIT_CODE"
    if [[ -e $TMP_EXIT_CODE ]]; then
        echo "$0: ERROR: cannot remove temporary exit code: $TMP_EXIT_CODE" 1>&2
        exit 14
    fi
    echo "$EXIT_CODE" > "$TMP_EXIT_CODE"
    if [[ ! -e $TMP_EXIT_CODE ]]; then
        echo "$0: ERROR: cannot create temporary exit code: $TMP_EXIT_CODE" 1>&2
        exit 15
    fi
elif [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: because of -n, temporary exit code is not used: $TMP_EXIT_CODE" 1>&2
fi


# generate new Email address for each user
#
sed -E -e 's/\s*#.*//' -e 's/\s\s*$//' -e 's/^\s\s*//' -e '/^\s*$/d' "$FILE" | while read -r EMAIL; do

    # process this email address
    #
    if [[ -z $NOOP ]]; then

	# generate an account and email for this email address
	#
	if [[ $V_FLAG -ge 1 ]]; then
	    echo "$0: debug[3]: about to run: $NEW_USER_SH -v $V_FLAG -t $TOPDIR -T $TMPDIR -g $GEN_ACCT_SH -r $REG_EMAIL_SH -p $IOCCC_PASSWD $EMAIL" 1>&2
	fi
	"$NEW_USER_SH" -v "$V_FLAG" -t "$TOPDIR" -T "$TMPDIR" -g "$GEN_ACCT_SH" -r "$REG_EMAIL_SH" -p "$IOCCC_PASSWD" "$EMAIL"
	status="$?"
	if [[ $status -ne 0 ]]; then
	    echo "$0: ERROR: $NEW_USER_SH -v $V_FLAG -t $TOPDIR -T $TMPDIR -g $GEN_ACCT_SH -r $REG_EMAIL_SH -p $IOCCC_PASSWD $EMAIL failed, error: $status" 1>&2
	    echo 1 > "$TMP_EXIT_CODE" # exit 1
	fi

	# sleep between email processing
	#
	# We do not want to appear to "flood" the mail relay with too many Email messages.
	#
	if [[ $WAIT_SECS -gt 0 ]]; then
	    if [[ $V_FLAG -ge 1 ]]; then
		echo "$0: debug[3]: about to run: sleep $WAIT_SECS" 1>&2
	    fi
	    sleep "$WAIT_SECS"
	fi

    # case: -n - do no action
    #
    elif [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: because of -n, did not run: $NEW_USER_SH -v $V_FLAG -t $TOPDIR -T $TMPDIR -g $GEN_ACCT_SH -r $REG_EMAIL_SH -p $IOCCC_PASSWD $EMAIL" 1>&2
    fi

done
if [[ -z $NOOP ]]; then
    EXIT_CODE=$(< "$TMP_EXIT_CODE")
    if [[ -z $EXIT_CODE ]]; then
	echo "$0: ERROR: temporary exit file is empty: $TMP_EXIT_CODE" 1>&2
	exit 16
    fi
fi


# All Done!!! All Done!!! -- Jessica Noll, Age 2
#
if [[ -z $NOOP ]]; then
    if [[ $EXIT_CODE -ne 0 ]]; then
	echo "$0: Warning: about to exit $EXIT_CODE" 1>&2
    fi
    rm -f "$TMP_EXIT_CODE"
elif [[ $V_FLAG -ge 1 ]]; then
    echo  "$0: debug[1]: -n disabled execution of: rm -f $TMP_EXIT_CODE" 1>&2
fi
exit "$EXIT_CODE"
