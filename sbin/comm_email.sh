#!/usr/bin/env bash
#
# comm_email.sh - print email addresses from 2nd file that are not in 1st file
#
# Given two files of addresses (one per line), print the print email addresses
# from 2nd file that are not in 1st file.
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
export LC_ALL="C"
export LANG="C"
export LC_NUMERIC="C"


# setup
#
export VERSION="2.2.0 2025-03-13"
NAME=$(basename "$0")
export NAME
export V_FLAG=0
#
export TMPDIR
if [[ -z $TMPDIR ]]; then
    TMPDIR="/tmp"
fi
#
export COMM_TOOL
if [[ -z $COMM_TOOL ]]; then
    COMM_TOOL=$(type -P comm)
    if [[ -z "$COMM_TOOL" ]]; then
	COMM_TOOL="/usr/bin/comm"
    fi
fi
#
export SORT_TOOL
if [[ -z $SORT_TOOL ]]; then
    SORT_TOOL=$(type -P sort)
    if [[ -z "$SORT_TOOL" ]]; then
	SORT_TOOL="/usr/bin/comm"
    fi
fi


# usage
#
export USAGE="usage: $0 [-h] [-v level] [-V] [-T tmpdir] [-c comm] [-s sort] file1.lst file2.lst [output.lst]

	-h		print help message and exit
	-v level	set verbosity level (def level: 0)
	-V		print version string and exit

	-T tmpdir	form temp files under tmpdir (def: $TMPDIR)

	-c comm	        use comm tool (def: $COMM_TOOL)
	-s sort		use soer tool (def: $SORT_TOOL)

	file1.lst	1st file containing email addresses, one per line
	file2.lst	2nd file containing email addresses, one per line

	[output.lst]	write email addresses from 1st file not in 2nd file (def: exit 0 if same email addresses in both files)

Exit codes:
     0         output.lst given and contains zero or more email addresses from 1st file not in 2nd file
     1	       output.lst not given, and some email addresses from 1st file not in 2nd file
     2         -h and help string printed or -V and version string printed
     3         command line error
     4	       comm tool ar sort tool not found or exited non-zero
     5	       unable to read for sorting, file1.lst or file2.lst files
     6	       update to update output.lst
 >= 10         internal error

$NAME version: $VERSION"


# parse command line
#
while getopts :hv:VT:c:s: flag; do
  case "$flag" in
    h) echo "$USAGE" 1>&2
	exit 2
	;;
    v) V_FLAG="$OPTARG"
	;;
    V) echo "$VERSION"
	exit 2
	;;
    T) TMPDIR="$OPTARG"
	;;
    c) COMM_TOOL="$OPTARG"
        ;;
    s) SORT_TOOL="$OPTARG"
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
export FILE1_LST FILE2_LST OUTPUT_LST
case "$#" in
    2) FILE1_LST="$1"
       FILE2_LST="$2"
       ;;
    3) FILE1_LST="$1"
       FILE2_LST="$2"
       OUTPUT_LST="$3"
       ;;
    *) echo "$0: ERROR: expected 2 or 3 args, found: $#" 1>&2
       exit 3
       ;;
esac


# file1.lst must be a readable file
#
if [[ ! -e $FILE1_LST ]]; then
    echo "$0: ERROR: file1.lst file does not exist: $FILE1_LST" 1>&2
    exit 5
fi
if [[ ! -f $FILE1_LST ]]; then
    echo "$0: ERROR: file1.lst is not a file: $FILE1_LST" 1>&2
    exit 5
fi
if [[ ! -r $FILE1_LST ]]; then
    echo "$0: ERROR: file1.lst is not a readable file: $FILE1_LST" 1>&2
    exit 5
fi


# file2.lst must be a readable file
#
if [[ ! -e $FILE2_LST ]]; then
    echo "$0: ERROR: file2.lst file does not exist: $FILE2_LST" 1>&2
    exit 5
fi
if [[ ! -f $FILE2_LST ]]; then
    echo "$0: ERROR: file2.lst is not a file: $FILE2_LST" 1>&2
    exit 5
fi
if [[ ! -r $FILE2_LST ]]; then
    echo "$0: ERROR: file2.lst is not a readable file: $FILE2_LST" 1>&2
    exit 5
fi


# print running info if verbose
#
# If -v 3 or higher, print exported variables in order that they were exported.
#
if [[ $V_FLAG -ge 3 ]]; then
    echo "$0: debug[3]: LC_ALL=$LC_ALL" 1>&2
    echo "$0: debug[3]: LANG=$LANG" 1>&2
    echo "$0: debug[3]: LC_NUMERIC=$LC_NUMERIC" 1>&2
    echo "$0: debug[3]: VERSION=$VERSION" 1>&2
    echo "$0: debug[3]: NAME=$NAME" 1>&2
    echo "$0: debug[3]: V_FLAG=$V_FLAG" 1>&2
    echo "$0: debug[3]: TMPDIR=$TMPDIR" 1>&2
    echo "$0: debug[3]: COMM_TOOL=$COMM_TOOL" 1>&2
    echo "$0: debug[3]: FILE1_LST=$FILE1_LST" 1>&2
    echo "$0: debug[3]: FILE2_LST=$FILE2_LST" 1>&2
    echo "$0: debug[3]: OUTPUT_LST=$OUTPUT_LST" 1>&2
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


# form sorted file1.lst file
#
export TMP_SORTED_FILE1_LST="$TMPDIR/.tmp.$NAME.SORTED_FILE1_LST.$$.tmp"
if [[ $V_FLAG -ge 3 ]]; then
    echo  "$0: debug[3]: sorted file1.lst file: $TMP_SORTED_FILE1_LST" 1>&2
fi
trap 'rm -f $TMP_SORTED_FILE1_LST; exit' 0 1 2 3 15
rm -f "$TMP_SORTED_FILE1_LST"
if [[ -e $TMP_SORTED_FILE1_LST ]]; then
    echo "$0: ERROR: cannot remove sorted file1.lst file: $TMP_SORTED_FILE1_LST" 1>&2
    exit 14
fi
: >  "$TMP_SORTED_FILE1_LST"
if [[ ! -e $TMP_SORTED_FILE1_LST ]]; then
    echo "$0: ERROR: cannot create sorted file1.lst file: $TMP_SORTED_FILE1_LST" 1>&2
    exit 15
fi


# form sorted file2.lst file
#
export TMP_SORTED_FILE2_LST="$TMPDIR/.tmp.$NAME.SORTED_FILE2_LST.$$.tmp"
if [[ $V_FLAG -ge 3 ]]; then
    echo  "$0: debug[3]: sorted file2.lst file: $TMP_SORTED_FILE2_LST" 1>&2
fi
trap 'rm -f $TMP_SORTED_FILE1_LST $TMP_SORTED_FILE2_LST; exit' 0 1 2 3 15
rm -f "$TMP_SORTED_FILE2_LST"
if [[ -e $TMP_SORTED_FILE2_LST ]]; then
    echo "$0: ERROR: cannot remove sorted file2.lst file: $TMP_SORTED_FILE2_LST" 1>&2
    exit 16
fi
: >  "$TMP_SORTED_FILE2_LST"
if [[ ! -e $TMP_SORTED_FILE2_LST ]]; then
    echo "$0: ERROR: cannot create sorted file2.lst file: $TMP_SORTED_FILE2_LST" 1>&2
    exit 17
fi


# form temporary output file
#
export TMP_OUTPUT="$TMPDIR/.tmp.$NAME.OUTPUT.$$.tmp"
if [[ $V_FLAG -ge 3 ]]; then
    echo  "$0: debug[3]: temporary output file: $TMP_OUTPUT" 1>&2
fi
trap 'rm -f $TMP_SORTED_FILE1_LST $TMP_SORTED_FILE2_LST $TMP_OUTPUT; exit' 0 1 2 3 15
rm -f "$TMP_OUTPUT"
if [[ -e $TMP_OUTPUT ]]; then
    echo "$0: ERROR: cannot remove output file: $TMP_OUTPUT" 1>&2
    exit 18
fi
: >  "$TMP_OUTPUT"
if [[ ! -e $TMP_OUTPUT ]]; then
    echo "$0: ERROR: cannot create output file: $TMP_OUTPUT" 1>&2
    exit 19
fi


# must have an executable sed tool
#
if [[ ! -x $COMM_TOOL ]]; then
    echo "$0: ERROR: cannot find comm executable: $COMM_TOOL" 1>&2
    exit 4
fi


# must have an executable sed tool
#
if [[ ! -x $SORT_TOOL ]]; then
    echo "$0: ERROR: cannot find sort executable: $SORT_TOOL" 1>&2
    exit 4
fi


# sort file1.lst contents
#
if [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: about to run: $SORT_TOOL -u $FILE1_LST -o $TMP_SORTED_FILE1_LST" 1>&2
fi
"$SORT_TOOL" -u "$FILE1_LST" -o "$TMP_SORTED_FILE1_LST"
status="$?"
if [[ $status -ne 0 ]]; then
    echo "$0: ERROR: $SORT_TOOL -u $FILE1_LST -o $TMP_SORTED_FILE1_LST failed, error: $status" 1>&2
    exit 4
fi
if [[ $V_FLAG -ge 5 ]]; then
    echo "$0: debug[5]: TMP_SORTED_FILE1_LST from $FILE1_LST starts below" 1>&2
    cat "$TMP_SORTED_FILE1_LST" 1>&2
    echo "$0: debug[5]: TMP_SORTED_FILE1_LST from $FILE1_LST ends above" 1>&2
fi


# sort file2.lst contents
#
if [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: about to run: $SORT_TOOL -u $FILE2_LST -o $TMP_SORTED_FILE2_LST" 1>&2
fi
"$SORT_TOOL" -u "$FILE2_LST" -o "$TMP_SORTED_FILE2_LST"
status="$?"
if [[ $status -ne 0 ]]; then
    echo "$0: ERROR: $SORT_TOOL -u $FILE2_LST -o $TMP_SORTED_FILE2_LST failed, error: $status" 1>&2
    exit 4
fi
if [[ $V_FLAG -ge 5 ]]; then
    echo "$0: debug[5]: TMP_SORTED_FILE2_LST from $FILE2_LST starts below" 1>&2
    cat "$TMP_SORTED_FILE2_LST" 1>&2
    echo "$0: debug[5]: TMP_SORTED_FILE2_LST from $FILE2_LST ends above" 1>&2
fi


# extract email address from file1.lst that are not in file2.lst and write to the temporary file
#
if [[ $V_FLAG -ge 1 ]]; then
    echo "$0: debug[1]: about to run: $COMM_TOOL -23 $TMP_SORTED_FILE1_LST $TMP_SORTED_FILE2_LST > $TMP_OUTPUT" 1>&2
fi
"$COMM_TOOL" -23 "$TMP_SORTED_FILE1_LST" "$TMP_SORTED_FILE2_LST" > "$TMP_OUTPUT"
status="$?"
if [[ $status -ne 0 ]]; then
    echo "$0: ERROR: $COMM_TOOL -23 $TMP_SORTED_FILE1_LST $TMP_SORTED_FILE2_LST > $TMP_OUTPUT failed, error: $status" 1>&2
    exit 4
fi


# case: output.lst arg given
#
# move extracted email addresses to output.lst
#
if [[ -n $OUTPUT_LST ]]; then
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: about to run: mv -f $TMP_OUTPUT $OUTPUT_LST" 1>&2
    fi
    mv -f "$TMP_OUTPUT" "$OUTPUT_LST"
    status="$?"
    if [[ $status -ne 0 ]]; then
	echo "$0: ERROR: mv -f $TMP_OUTPUT $OUTPUT_LST failed, error: $status" 1>&2
	exit 6
    fi


# case: output.lst arg NOT given and different email addresses in files
#
# exit 0 if 1st and 2nd files have same email addresses
#
elif [[ -s $TMP_OUTPUT ]]; then

    # case: files differ
    #
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: no output.lst arg, different email addresses in files" 1>&2
    fi
    exit 1


# case: output.lst arg NOT given and same email addresses in both files
#
else

    # case: files the same
    #
    if [[ $V_FLAG -ge 1 ]]; then
	echo "$0: debug[1]: no output.lst arg, same email addresses in both files" 1>&2
    fi
fi


# All Done!!! All Done!!! -- Jessica Noll, Age 2
#
exit 0
