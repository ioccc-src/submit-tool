#!/usr/bin/env python3
#
# set_slot_status.py - Modify the status comment of a user's slot

"""
set_slot_status.py - Modify the status comment of a user's slot
"""


# system imports
#
import sys
import argparse
import os
import locale


# import the ioccc python utility code
#
# Sort the import list with: sort -d -u
#
from iocccsubmit import \
        MAX_SUBMIT_SLOT, \
        change_startup_appdir, \
        error, \
        info, \
        lookup_username, \
        prerr, \
        return_last_errmsg, \
        return_slot_json_filename, \
        setup_logger, \
        update_slot_status


# set_slot_status.py version
#
# NOTE: Use string of the form: "x.y[.z] YYYY-MM-DD"
#
VERSION = "2.6.0 2025-03-13"


def main():
    """
    Main routine when run as a program.
    """

    # setup
    #
    program = os.path.basename(__file__)
    set_collected_to_true = False

    # IOCCC requires use of C locale
    #
    try:
        locale.setlocale(locale.LC_ALL, 'C')
    except locale.Error:
        pass

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
    parser.add_argument('-c', '--collected',
                        help='Set collected to True (def: do not change collected)',
                        action='store_true')
    parser.add_argument('username', help='IOCCC submit server username')
    parser.add_argument('slot_num', help=f'slot number from 0 to {MAX_SUBMIT_SLOT}')
    parser.add_argument('status', help='slot status string')
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

    # -c - force collected to be set to false
    #
    if args.collected:
        set_collected_to_true = True

    # verify arguments
    #
    username = args.username
    if not lookup_username(username):
        prerr(f'ERROR via print: lookup_username for  username: {username} '
              f'failed: {return_last_errmsg()}')
        sys.exit(4)
    slot_num = int(args.slot_num)
    slot_json_file = return_slot_json_filename(username, slot_num)
    if not slot_json_file:
        prerr(f'{program}: invalid slot number: {slot_num} for username: {username}')
        prerr(f'{program}: slot numbers must be between 0 and {MAX_SUBMIT_SLOT}')
        sys.exit(5)
    status = args.status

    # update slot JSON file
    #
    if not update_slot_status(username, slot_num, status, set_collected_to_true):
        prerr(f'{program}: update_slot_status for username: {username} slot_num: {slot_num} '
              f'failed: {return_last_errmsg()}')
        sys.exit(6)

    # no option selected
    #
    if set_collected_to_true:
        info(f'{program}: username: {username} slot_num: {slot_num} collected: True status: {status}')
        prerr(f'{program}: username: {username} slot_num: {slot_num} collected: True status: {status}')
    else:
        info(f'{program}: username: {username} slot_num: {slot_num} collected: ((unchanged)) status: {status}')
        prerr(f'{program}: username: {username} slot_num: {slot_num} collected: ((unchanged)) status: {status}')
    sys.exit(0)


# case: run from the command line
#
if __name__ == '__main__':
    main()
