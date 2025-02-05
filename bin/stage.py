#!/usr/bin/env python3
#
# stage.py - Stage a slot's submit file into a staging directory

"""
stage.py - Stage a slot's submit file into a staging directory
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
        cd_appdir, \
        change_startup_appdir, \
        check_slot_num_arg, \
        check_username_arg, \
        debug, \
        error, \
        prerr, \
        return_last_errmsg, \
        setup_logger, \
        stage_submit, \
        warning


# ioccc_date.py version
#
# NOTE: Use string of the form: "x.y[.z] YYYY-MM-DD"
#
VERSION = "2.0.0 2025-02-04"


# pylint: disable=too-many-statements
#
def main():
    """
    Main routine when run as a program.
    """

    # setup
    #
    program = os.path.basename(__file__)
    hexdigest = "."
    unexpected_count = 0

    # parse args
    #
    parser = argparse.ArgumentParser(
                description=" Stage a slot's submit file into a staging directory",
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
    parser.add_argument('slot_path',
                        help="path, usually from topdir, of the slot directory",
                        nargs=1,
                        type=str)
    args = parser.parse_args()

    # setup logging according to -l logtype -L dbglvl
    #
    setup_logger(args.log, args.level)

    # -t topdir - set the path to the top level app directory
    #
    if args.topdir:
        if not change_startup_appdir(args.topdir[0]):
            error(f'{program}: change_startup_appdir failed: <<{return_last_errmsg()}>>')
            prerr(f'{program}: change_startup_appdir failed: <<{return_last_errmsg()}>>')
            print('exit.3 0')
            sys.exit(3)

    # cd the APPDIR directory
    #
    # This is usually /var/ioccc, but could be '.' or whatever -t topdir set
    #
    cd_appdir()

    # parse slot path into username and slot number#
    #
    slot_path = args.slot_path[0]
    debug(f'{program}: slot_path: {slot_path}')
    if not Path(slot_path).is_dir():
        error(f'{program}: slot_path is not a directory: {slot_path}')
        prerr(f'{program}: slot_path is not a directory: {slot_path}')
        print('exit.4 0')
        sys.exit(4)
    slot_num_str = os.path.basename(slot_path)
    if not slot_num_str.isdecimal():
        error(f'{program}: last component of slot_path: {slot_path} is not an integer: {slot_num_str}')
        prerr(f'{program}: last component of slot_path: {slot_path} is not an integer: {slot_num_str}')
        print('exit.5 0')
        sys.exit(5)
    slot_num = int(slot_num_str)
    debug(f'{program}: slot_num: {slot_num}')
    if not check_slot_num_arg(slot_num):
        # the above function call will have logged the error
        prerr(f'{program}: {return_last_errmsg()}')
        print('exit.6 0')
        sys.exit(6)
    partent_slot_path = os.path.dirname(slot_path)
    username = os.path.basename(partent_slot_path)
    debug(f'{program}: username: {username}')
    if not check_username_arg(username):
        # the above function call will have logged the error
        prerr(f'{program}: {return_last_errmsg()}')
        print('exit.7 0')
        sys.exit(7)

    # stage the submit file for this slot
    #
    hexdigest, unexpected_count = stage_submit(username, slot_num)
    if not isinstance(hexdigest, str) or not isinstance(unexpected_count, int):
        # the above function call will have logged the error
        prerr(f'{program}: stage_submit failed: <<{return_last_errmsg()}>>')
        if hexdigest is not None and not isinstance(hexdigest, str):
            error(f'{program}: stage_submit returned a non-string non-None hexdigest')
        prerr(f'{program}: hexdigest: {hexdigest}')
        if not isinstance(unexpected_count, int):
            error(f'{program}: stage_submit returned a non-int unexpected_count')
        prerr(f'{program}: unexpected_count: {unexpected_count}')
        print(f'exit.8 {unexpected_count}')
        sys.exit(8)

    # print success
    #
    # We print the SHA256 digest of the file moved into the staged
    #
    if unexpected_count > 0:
        warning('{program}: moved {unexpected_count} files into the unexpected directory')
    print(f'{hexdigest} {unexpected_count}')

    # All Done!!! All Done!!! -- Jessica Noll, Age 2
    #
    sys.exit(0)
#
# pylint: enable=too-many-statements


# case: run from the command line
#
if __name__ == '__main__':
    main()
