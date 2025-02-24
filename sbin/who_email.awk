#!/usr/bin/env awk
#
# who_email.awk - print email messages from Ecartis who email message
#
# usage:
#
#       awk [-v debug=level] -f sbin/who_email.awk who-ioccc
#
# About modes:
#
# 0 - waiting for '>> who' line
# 1 - read '>> who' line, now waiting for line that starts with 'Membership of list '
# 2 - read line that starts with 'Membership of list ', now reading email lines, waiting for empty/blank line
#
# NOTE: When mode == 2 and a empty/blank line is read, mode will return to 0.
# NOTE: When mode == 2, and a non-empty/blank line is read, the 1st field will be printed

# start
#
BEGIN {

    # setup
    #
    VERSION="2.0.0 2025-02-23";

    # if debug is empty, set debug to 0
    #
    if (length(debug) == 0) {
	debug = 0;
    }

    # set the mode
    #
    if (debug > 0) {
	print "DEBUG: enter mode 0";
    }
    mode = 0;
}


# case mode 0: waiting for '>> who' line
#
mode == 0 && $0 !~ /^>> who/ {
    line = substr($0, 1, length($0)-1);
    if (debug > 0) {
	print "DEBUG: mode 0: waiting for who line: ((" line "))";
    }
    next;
}


# case mode 0: read '>> who' line
#
# enter mode 1
#
mode == 0 && $0 ~ /^>> who/ {
    line = substr($0, 1, length($0)-1);
    if (debug > 0) {
	print "DEBUG: mode 0: read who line: ((" line "))";
	print "DEBUG: enter mode 1";
    }
    mode = 1;
    next;
}


# case mode 1: read '>> who' line, now waiting for line that starts with 'Membership of list '
#
# enter mode 2
#
mode == 1 && $0 ~ /^Membership of list / {
    line = substr($0, 1, length($0)-1);
    if (debug > 0) {
	print "DEBUG: mode 1: read line that starts with ((Membership of list )) line: ((" line "))";
	print "DEBUG: enter mode 2";
    }
    mode = 2;
    next;
}


# case mode 2: read line that starts with 'Membership of list ', now reading email lines
#
mode == 2 {
    line = substr($0, 1, length($0)-1);
    if (debug > 0) {
	print "DEBUG: mode 2: reading email line: ((" line "))";
    }
    if (length(line) > 0) {
	print $1;
    } else {
	if (debug > 0) {
	    print "DEBUG: mode 2: read empty/blank line";
	    print "DEBUG: enter mode 0";
	}
	mode = 0;
    }
    next;
}


# All Done!!! All Done!!! -- Jessica Noll, Age 2
#
END {
    if (debug > 0) {
	print "DEBUG: All Done!!! All Done!!! -- Jessica Noll, Age 2"
    }
}
