#!/usr/bin/env bash
#
# who_extract.sh - extract mailing list email addresses from a mail message file
#
# Given a "who-ioccc" file that contains the contents of an email message from the
# FreeLists.org mailing list server containing the result of a who command,
# we extract mailing list email addresses, if any.  If no email addresses
# are found, or if the mail message file is empty, we do nothing.
# Otherwise of one or more email addresses are extracted, replace the
# contents of the "freelists.lst" file with their contents.
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
export VERSION="2.2.1 2025-11-17"
NAME=$(basename "$0")
export NAME
export V_FLAG=0
#
export TOPDIR
if [[ -z $TOPDIR ]]; then
    TOPDIR="/var/ioccc"
    if [[ ! -d $TOPDIR ]]; then
	# not on submit server, assume testing in .
	TOPDIR="."
    fi
fi
#
export TMPDIR
if [[ -z $TMPDIR ]]; then
    TMPDIR="$TOPDIR/tmp"
fi
#
export IOCCC_RC
if [[ -z $IOCCC_RC ]]; then
    IOCCC_RC="$HOME/.ioccc.rc"
fi
#
export CAP_I_FLAG=
#
export AWK_TOOL
if [[ -z $AWK_TOOL ]]; then
    AWK_TOOL=$(type -P awk)
    if [[ -z "$AWK_TOOL" ]]; then
	AWK_TOOL="/usr/bin/awk"
    fi
fi
#
export WHO_EMAIL_AWK
if [[ -z $WHO_EMAIL_AWK ]]; then
    WHO_EMAIL_AWK="/usr/ioccc/sbin/who_email.awk"
fi


# usage
#
export USAGE="usage: $0 [-h] [-v level] [-V] [-t appdir] [-T tmpdir] [-i ioccc.rc] [-I] [-a awk] [-A who_email]
	who-ioccc freelists.lst

	-h		print help message and exit
	-v level	set verbosity level (def level: 0)
	-V		print version string and exit

	-t appdir	app directory path (def: $TOPDIR)
	-T tmpdir	form temp files under tmpdir (def: $TMPDIR)

	-i ioccc.rc	Use ioccc.rc as the rc startup file (def: $IOCCC_RC)
	-I		Do not use any rc startup file (def: do)

	-a awk	        use awk tool (def: $AWK_TOOL)
	-A who_email	use who_email awk script (def: $WHO_EMAIL_AWK)

	who-ioccc	Ecartis email for who command
	freelists.lst	file to update if email addresses are found in who-ioccc

Exit codes:
     0         all OK or cannot read who-ioccc or no email addresses in who-ioccc
     1	       unable to update freelists.lst
     2         -h and help string printed or -V and version string printed
     3         command line error
     4         topdir is not a directory, or cannot cd to topdir
     5	       who_email.awk is not a readable file
 >= 10         internal error

$NAME version: $VERSION"


# parse command line
#
while getopts :hv:Vt:T:i:Ia:A: flag; do
  case "$flag" in
    h) echo "$USAGE" 1>&2
	exit 2
	;;
    v) V_FLAG="$OPTARG"
	;;
    V) echo "$VERSION"
	exit 2
	;;
    t) TOPDIR="$OPTARG"
	;;
    T) TMPDIR="$OPTARG"
	;;
    i) IOCCC_RC="$OPTARG"
        ;;
    I) CAP_I_FLAG="true"
        ;;
    a) AWK_TOOL="$OPTARG"
        ;;
    A) WHO_EMAIL_AWK="$OPTARG"
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
if [[ $# -ne 2 ]]; then
    echo "$0: ERROR: expected 2 args, found: $#" 1>&2
    exit 3
fi
export WHO_IOCCC="$1"
export FREELISTS_LST="$2"


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
    echo "$0: debug[3]: TOPDIR=$TOPDIR" 1>&2
    echo "$0: debug[3]: TMPDIR=$TMPDIR" 1>&2
    echo "$0: debug[3]: IOCCC_RC=$IOCCC_RC" 1>&2
    echo "$0: debug[3]: CAP_I_FLAG=$CAP_I_FLAG" 1>&2
    echo "$0: debug[3]: AWK_TOOL=$AWK_TOOL" 1>&2
    echo "$0: debug[3]: WHO_EMAIL_AWK=$WHO_EMAIL_AWK" 1>&2
    echo "$0: debug[3]: WHO_IOCCC=$WHO_IOCCC" 1>&2
    echo "$0: debug[3]: FREELISTS_LST=$FREELISTS_LST" 1>&2
fi


# do nothing if who-ioccc is not a non-empty readable file
#
if [[ ! -e $WHO_IOCCC ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: who-ioccc does not exist, nothing to do: $WHO_IOCCC" 1>&2
    fi
    exit 0
fi
if [[ ! -f $WHO_IOCCC ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: who-ioccc is not a file, nothing to do: $WHO_IOCCC" 1>&2
    fi
    exit 0
fi
if [[ ! -s $WHO_IOCCC ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: who-ioccc is an empty file, nothing to do: $WHO_IOCCC" 1>&2
    fi
    exit 0
fi
if [[ ! -r $WHO_IOCCC ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: who-ioccc is not a reaaable file, nothing to do: $WHO_IOCCC" 1>&2
    fi
    exit 0
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


# must have readable who_email.awk file
#
if [[ ! -e $WHO_EMAIL_AWK ]]; then
    echo "$0: ERROR: who_email.awk does not exist: $WHO_EMAIL_AWK" 1>&2
    exit 5
fi
if [[ ! -f $WHO_EMAIL_AWK ]]; then
    echo "$0: ERROR: who_email.awk is not a file: $WHO_EMAIL_AWK" 1>&2
    exit 5
fi
if [[ ! -r $WHO_EMAIL_AWK ]]; then
    echo "$0: ERROR: who_email.awk is not a readable file: $WHO_EMAIL_AWK" 1>&2
    exit 5
fi


# must have an executable awk tool
#
if [[ ! -x $AWK_TOOL ]]; then
    echo "$0: ERROR: cannot find awk executable: $AWK_TOOL" 1>&2
    exit 14
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
    exit 15
fi
: >  "$TMP_OUTPUT"
if [[ ! -e $TMP_OUTPUT ]]; then
    echo "$0: ERROR: cannot create output file: $TMP_OUTPUT" 1>&2
    exit 16
fi


# extract email address from who-ioccc file
#
if [[ $V_FLAG -ge 5 ]]; then
    echo "$0: debug[5]: $AWK_TOOL -f $WHO_EMAIL_AWK -v debug=$V_FLAG $WHO_IOCCC output starts below" 1>&2
    "$AWK_TOOL" -f "$WHO_EMAIL_AWK" -v debug="$V_FLAG" "$WHO_IOCCC"
    echo "$0: debug[5]: $AWK_TOOL -f $WHO_EMAIL_AWK -v debug=$V_FLAG $WHO_IOCCC output ends above" 1>&2
fi
if [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: about to run: $AWK_TOOL -f $WHO_EMAIL_AWK $WHO_IOCCC > $TMP_OUTPUT" 1>&2
fi
"$AWK_TOOL" -f "$WHO_EMAIL_AWK" "$WHO_IOCCC" > "$TMP_OUTPUT"
status="$?"
if [[ $status -ne 0 ]]; then
    echo "$0: ERROR: $AWK_TOOL -f $WHO_EMAIL_AWK $WHO_IOCCC > $TMP_OUTPUT failed, error: $status" 1>&2
    exit 17
fi


# do nothing if no email addresses were extracted
#
if [[ ! -s $TMP_OUTPUT ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: no Ecartis who email addresses found, nothing to do: $WHO_IOCCC" 1>&2
    fi
    exit 0
fi


# move extracted email addresses to freelists.lst
#
if [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: about to run: mv -f $TMP_OUTPUT $FREELISTS_LST" 1>&2
fi
mv -f "$TMP_OUTPUT" "$FREELISTS_LST"
status="$?"
if [[ $status -ne 0 ]]; then
    echo "$0: ERROR: mv -f $TMP_OUTPUT $FREELISTS_LST failed, error: $status" 1>&2
    exit 1
fi


# All Done!!! All Done!!! -- Jessica Noll, Age 2
#
exit 0
