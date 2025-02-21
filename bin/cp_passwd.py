#!/usr/bin/env python3
#
# cp_passwd.py - copy the IOCCC submit server password file

"""
cp_passwd.py - copy the IOCCC submit server password file
"""


# system imports
#
import sys
import argparse
import os


# import from modules
#
from pathlib import Path


# import the ioccc python utility code
#
# Sort the import list with: sort -d -u
#
from iocccsubmit import \
        change_startup_appdir, \
        copy_pwfile_under_lock, \
        error, \
        info, \
        prerr, \
        return_last_errmsg, \
        setup_logger, \
        warning


# set_slot_status.py version
#
# NOTE: Use string of the form: "x.y[.z] YYYY-MM-DD"
#
VERSION = "1.0.0 2025-02-21"


def main():
    """
    Main routine when run as a program.
    """

    # setup
    #
    program = os.path.basename(__file__)

    # parse args
    #
    parser = argparse.ArgumentParser(
                description="Modify the status comment of a user's slot",
                epilog=f'{program} version: {VERSION}')
    parser.add_argument('-t', '--topdir',
                        help="app directory path",
                        metavar='appdir',
                        nargs=1)
    parser.add_argument('-l', '--log',
                        help="log via: stdout stderr syslog none (def: syslog)",
                        default="syslog",
                        action="store",
                        metavar='logtype',
                        type=str)
    parser.add_argument('-L', '--level',
                        help="set log level: dbg debug info warn warning error crit critical (def: info)",
                        default="info",
                        action="store",
                        metavar='dbglvl',
                        type=str)
    parser.add_argument('newfile', help='copy submit server password file to newfile')
    args = parser.parse_args()

    # setup logging according to -l logtype -L dbglvl
    #
    setup_logger(args.log, args.level)

    # -t topdir - set the path to the top level app directory
    #
    if args.topdir:
        if not change_startup_appdir(args.topdir[0]):
            error(f'{program}: change_startup_appdir failed: {return_last_errmsg()}')
            prerr(f'{program}: change_startup_appdir failed: {return_last_errmsg()}')
            sys.exit(3)

    # remove any existing newfile
    #
    try:
        file_to_rem = Path(args.newfile)
        if file_to_rem.exists():
            try:
                file_to_rem.unlink()
            except OSError as errcode:
                warning(f'{program}: rm -f {args.newfile} failed: <<{errcode}>>')
                sys.exit(4)
    except OSError:
        warning(f'{program}: cannot determine if newfile exits: {args.newfile}')
        sys.exit(5)

    # copy IOCCC submit server password file
    #
    if not copy_pwfile_under_lock(args.newfile):
        prerr(f'{program}: change_startup_appdir failed: {return_last_errmsg()}')
        info(f'{program}: cannot determine if newfile exits: {args.newfile}')
        sys.exit(5)


    # All Done!!! All Done!!! -- Jessica Noll, Age 2
    #
    sys.exit(0)


# case: run from the command line
#
if __name__ == '__main__':
    main()
