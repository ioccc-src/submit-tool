#!/usr/bin/env bash
#
# filter.sh - filter email addresses
#
# Given a file of addresses, one per line, apply a sed filter and
# write the result to stdout.
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


# setup
#
export VERSION="2.0.0 2025-02-23"
NAME=$(basename "$0")
export NAME
export V_FLAG=0
#
export SED_TOOL
if [[ -z $SED_TOOL ]]; then
    SED_TOOL=$(type -P sed)
    if [[ -z "$SED_TOOL" ]]; then
	SED_TOOL="/usr/bin/sed"
    fi
fi


# usage
#
export USAGE="usage: $0 [-h] [-v level] [-V] [-s sed] freelists.lst filter.sed

	-h		print help message and exit
	-v level	set verbosity level (def level: 0)
	-V		print version string and exit

	-s sed	        use sed tool (def: $SED_TOOL)

	freelists.lst	file to update if email addresses are found in who-ioccc
	filter.sed	sed filter to apply to freelists.lst

Exit codes:
     0         all OK or cannot read who-ioccc or no email addresses in who-ioccc
     1	       unable to read freelists.lst
     2         -h and help string printed or -V and version string printed
     3         command line error
     4	       unable to read filter.sed, or sed script failed
 >= 10         internal error

$NAME version: $VERSION"


# parse command line
#
while getopts :hv:Vts: flag; do
  case "$flag" in
    h) echo "$USAGE" 1>&2
	exit 2
	;;
    v) V_FLAG="$OPTARG"
	;;
    V) echo "$VERSION"
	exit 2
	;;
    s) SED_TOOL="$OPTARG"
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
export FREELISTS_LST="$1"
export FILTER_SED="$2"


# freelists.lst must be a readable file
#
if [[ ! -e $FREELISTS_LST ]]; then
    echo "$0: ERROR: freelists.lst file does not exist: $FREELISTS_LST" 1>&2
    exit 1
fi
if [[ ! -f $FREELISTS_LST ]]; then
    echo "$0: ERROR: freelists.lst is not a file: $FREELISTS_LST" 1>&2
    exit 1
fi
if [[ ! -r $FREELISTS_LST ]]; then
    echo "$0: ERROR: freelists.lst is not a readable file: $FREELISTS_LST" 1>&2
    exit 1
fi


# filter.sed must be a readable file
#
if [[ ! -e $FILTER_SED ]]; then
    echo "$0: ERROR: filter.sed file does not exist: $FILTER_SED" 1>&2
    exit 4
fi
if [[ ! -f $FILTER_SED ]]; then
    echo "$0: ERROR: filter.sed is not a file: $FILTER_SED" 1>&2
    exit 4
fi
if [[ ! -r $FILTER_SED ]]; then
    echo "$0: ERROR: filter.sed is not a readable file: $FILTER_SED" 1>&2
    exit 4
fi


# print running info if verbose
#
# If -v 3 or higher, print exported variables in order that they were exported.
#
if [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: VERSION=$VERSION" 1>&2
    echo "$0: debug[3]: NAME=$NAME" 1>&2
    echo "$0: debug[3]: V_FLAG=$V_FLAG" 1>&2
    echo "$0: debug[3]: SED_TOOL=$SED_TOOL" 1>&2
    echo "$0: debug[3]: FREELISTS_LST=$FREELISTS_LST" 1>&2
    echo "$0: debug[3]: FILTER_SED=$FILTER_SED" 1>&2
fi


# must have an executable sed tool
#
if [[ ! -x $SED_TOOL ]]; then
    echo "$0: ERROR: cannot find sed executable: $SED_TOOL" 1>&2
    exit 4
fi



# extract email address from who-ioccc file
#
if [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: about to run: $SED_TOOL -f $FILTER_SED -- $FREELISTS_LST" 1>&2
fi
"$SED_TOOL" -f "$FILTER_SED" -- "$FREELISTS_LST"
status="$?"
if [[ $status -ne 0 ]]; then
    echo "$0: ERROR: $SED_TOOL -f $FILTER_SED -- $FREELISTS_LST failed, error: $status" 1>&2
    exit 4
fi


# All Done!!! All Done!!! -- Jessica Noll, Age 2
#
exit 0
