#!/usr/bin/env bash
#
# new_user.sh - create an IOCCC submit server account and send notification Email
#
# We generate an new IOCCC submit server account, collect
# the account information and send email to the IOCCC registered user.
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
export VERSION="1.0.3 2025-02-17"
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
REG_EMAIL_SH=$(type -P reg_email.sh)
export REG_EMAIL_SH
if [[ -z $REG_EMAIL_SH ]]; then
    REG_EMAIL_SH="bin/reg_email.sh"
fi
export MAIL_HEAD="etc/mail.head"
export MAIL_TAIL="etc/mail.tail"
#
export NOOP=
export DO_NOT_PROCESS=


# usage
#
export USAGE="usage: $0 [-h] [-v level] [-V] [-n] [-N] [-t topdir] [-T tmpdir] [-g gen_acct] [-r reg_email] email

	-h		print help message and exit
	-v level	set verbosity level (def level: 0)
	-V		print version string and exit

	-n		go thru the actions, but do not update any files (def: do the action)
	-N		do not process anything, just parse arguments (def: process something)

	-t appdir	app directory path (def: $TOPDIR)
	-T tmpdir	form temp files under tmpdir (def: $TMPDIR)

	-g gen_acct	tool to generate a new IOCCC submit server account (def: $GEN_ACCT_SH)
	-r reg_email	tool to send a IOCCC submit server registration email (def: $REG_EMAIL_SH)

	email		email address that we registed with the IOCCC

Exit codes:
     0         all OK
     1         failed to generate an IOCCC submit server account, or send email to the user
     2         -h and help string printed or -V and version string printed
     3         command line error
     4         topdir is not a directory
     5         missing internal tool
     6         mail head and/or mail tail not a non-empty readable file
 >= 10         internal error

$NAME version: $VERSION"


# parse command line
#
while getopts :hv:VnNt:T:g:r: flag; do
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
	;;
    T) TMPDIR="$OPTARG"
	;;
    g) GEN_ACCT_SH="$OPTARG"
	;;
    r) REG_EMAIL_SH="$OPTARG"
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
export EMAIL="$1"
if [[ -z $EMAIL ]]; then
    echo "$0: ERROR: email arg is empty" 1>&2
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
    echo "$0: debug[3]: GEN_ACCT_SH=$GEN_ACCT_SH" 1>&2
    echo "$0: debug[3]: REG_EMAIL_SH=$REG_EMAIL_SH" 1>&2
    echo "$0: debug[3]: MAIL_HEAD=$MAIL_HEAD" 1>&2
    echo "$0: debug[3]: MAIL_TAIL=$MAIL_TAIL" 1>&2
    echo "$0: debug[3]: NOOP=$NOOP" 1>&2
    echo "$0: debug[3]: DO_NOT_PROCESS=$DO_NOT_PROCESS" 1>&2
    echo "$0: debug[3]: EMAIL=$EMAIL" 1>&2
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
    echo "$0: ERROR: gen_acct.sh not exeutable: $GEN_ACCT_SH" 1>&2
    exit 5
fi


# reg_email.sh must be executable
#
if [[ ! -x $REG_EMAIL_SH ]]; then
    echo "$0: ERROR: reg_email.sh not exeutable: $REG_EMAIL_SH" 1>&2
    exit 5
fi


# mail head and tail content files must be non-empty readable files
#
if [[ ! -e $MAIL_HEAD ]]; then
    echo "$0: ERROR: mail head content file does not exist: $MAIL_HEAD" 1>&2
    exit 6
fi
if [[ ! -f $MAIL_HEAD ]]; then
    echo "$0: ERROR: mail head content file not a file: $MAIL_HEAD" 1>&2
    exit 6
fi
if [[ ! -r $MAIL_HEAD ]]; then
    echo "$0: ERROR: mail head content file not a readable file: $MAIL_HEAD" 1>&2
    exit 6
fi
if [[ ! -s $MAIL_HEAD ]]; then
    echo "$0: ERROR: mail head content file not a non-empty readable file: $MAIL_HEAD" 1>&2
    exit 6
fi
if [[ ! -e $MAIL_TAIL ]]; then
    echo "$0: ERROR: mail tail content file does not exist: $MAIL_TAIL" 1>&2
    exit 6
fi
if [[ ! -f $MAIL_TAIL ]]; then
    echo "$0: ERROR: mail tail content file not a file: $MAIL_TAIL" 1>&2
    exit 6
fi
if [[ ! -r $MAIL_TAIL ]]; then
    echo "$0: ERROR: mail tail content file not a readable file: $MAIL_TAIL" 1>&2
    exit 6
fi
if [[ ! -s $MAIL_TAIL ]]; then
    echo "$0: ERROR: mail tail content file not a non-empty readable file: $MAIL_TAIL" 1>&2
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


# form temporary email message file
#
export TMP_EMAIL_MESSAGE="$TMPDIR/.tmp.$NAME.EMAIL_MESSAGE.$$.tmp"
if [[ $V_FLAG -ge 3 ]]; then
    echo  "$0: debug[3]: temporary new email message file: $TMP_EMAIL_MESSAGE" 1>&2
fi
trap 'rm -f $TMP_EMAIL_MESSAGE; exit' 0 1 2 3 15
rm -f "$TMP_EMAIL_MESSAGE"
if [[ -e $TMP_EMAIL_MESSAGE ]]; then
    echo "$0: ERROR: cannot remove new email message file: $TMP_EMAIL_MESSAGE" 1>&2
    exit 14
fi
: >  "$TMP_EMAIL_MESSAGE"
if [[ ! -e $TMP_EMAIL_MESSAGE ]]; then
    echo "$0: ERROR: cannot create new femail message file: $TMP_EMAIL_MESSAGE" 1>&2
    exit 15
fi


# form temporary new account info file
#
export TMP_NEW_ACCT_INFO="$TMPDIR/.tmp.$NAME.NEW_ACCT_INFO.$$.tmp"
if [[ $V_FLAG -ge 3 ]]; then
    echo  "$0: debug[3]: temporary new account info file: $TMP_NEW_ACCT_INFO" 1>&2
fi
trap 'rm -f $TMP_EMAIL_MESSAGE $TMP_NEW_ACCT_INFO; exit' 0 1 2 3 15
rm -f "$TMP_NEW_ACCT_INFO"
if [[ -e $TMP_NEW_ACCT_INFO ]]; then
    echo "$0: ERROR: cannot remove new account info file: $TMP_NEW_ACCT_INFO" 1>&2
    exit 16
fi
: >  "$TMP_NEW_ACCT_INFO"
if [[ ! -e $TMP_NEW_ACCT_INFO ]]; then
    echo "$0: ERROR: cannot create new account info file: $TMP_NEW_ACCT_INFO" 1>&2
    exit 17
fi


# generate an IOCCC submit server account
#
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to run: $GEN_ACCT_SH $EMAIL > $TMP_NEW_ACCT_INFO" 1>&1
    fi
    "$GEN_ACCT_SH" "$EMAIL" > "$TMP_NEW_ACCT_INFO"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: $GEN_ACCT_SH $EMAIL failed, error: $status" 1>&2
	exit 1
    fi
    if [[ ! -s $TMP_NEW_ACCT_INFO ]]; then
	echo "$0: ERROR: $GEN_ACCT_SH failed to output new account info content" 1>&2
	exit 1
    fi
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not run: $GEN_ACCT_SH $EMAIL > $TMP_NEW_ACCT_INFO" 1>&2
fi


# form the email message
#
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to run: cat $MAIL_HEAD $TMP_NEW_ACCT_INFO $MAIL_TAIL > $TMP_EMAIL_MESSAGE" 1>&1
    fi
    cat "$MAIL_HEAD" "$TMP_NEW_ACCT_INFO" "$MAIL_TAIL" > "$TMP_EMAIL_MESSAGE"
    status="$?"
    if [[ $status -ne 0 ]]; then
        echo "$0: ERROR: cat $MAIL_HEAD $TMP_NEW_ACCT_INFO $MAIL_TAIL > $TMP_EMAIL_MESSAGE failed, error: $status" 1>&2
        exit 1
    fi
    if [[ ! -s $TMP_EMAIL_MESSAGE ]]; then
        echo "$0: ERROR: failed to output new email message" 1>&2
        exit 1
    fi
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not run: cat $MAIL_HEAD $TMP_NEW_ACCT_INFO $MAIL_TAIL > $TMP_EMAIL_MESSAGE" 1>&2
fi


# send the email message
#
if [[ -z $NOOP ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to run: $REG_EMAIL_SH $TMP_EMAIL_MESSAGE $EMAIL" 1>&2
    fi
    "$REG_EMAIL_SH" "$TMP_EMAIL_MESSAGE" "$EMAIL"
    status="$?"
    if [[ $status -ne 0 ]]; then
        echo "$0: ERROR: $REG_EMAIL_SH $TMP_EMAIL_MESSAGE $EMAIL failed, error: $status" 1>&2
        exit 1
    fi
elif [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: because of -n, did not run: $REG_EMAIL_SH $TMP_EMAIL_MESSAGE $EMAIL" 1>&2
fi


# All Done!!! All Done!!! -- Jessica Noll, Age 2
#
exit 0
