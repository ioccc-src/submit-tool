#!/usr/bin/env python3
#
# email_pr.py - print email and/or username for IOCCC submit server accounts

"""
email_pr.py - print email and/or username for IOCCC submit server accounts
"""


# system imports
#
import sys
import argparse
import os

# import the ioccc python utility code
#
# Sort the import list with: sort -d -u
#
from iocccsubmit import \
        change_startup_appdir, \
        error, \
        lookup_email_by_username, \
        lookup_username, \
        lookup_username_by_email, \
        prerr, \
        read_pwfile, \
        return_last_errmsg, \
        set_ioccc_locale, \
        setup_logger


# ioccc_date.py version
#
# NOTE: Use string of the form: "x.y[.z] YYYY-MM-DD"
#
VERSION = "2.1.0 2025-03-13"


# pylint: disable=too-many-branches
# pylint: disable=too-many-statements
# pylint: disable=too-many-locals
#
def main():
    """
    Main routine when run as a program.
    """

    # setup
    #
    program = os.path.basename(__file__)
    print_email = True
    print_username = True
    print_none = False
    args_are_email = True
    print_comma = False

    # IOCCC requires use of C locale
    #
    set_ioccc_locale()

    # parse args
    #
    parser = argparse.ArgumentParser(
                description="Manage the IOCCC start and/or end dates",
                epilog=f'{program} version: {VERSION}')
    parser.add_argument('-t', '--topdir',
                        help="app directory path",
                        metavar='appdir',
                        nargs=1)
    parser.add_argument('-s', '--silence',
                        help="silence printing (def: print email and username)",
                        metavar='{e,u,eu,ue}',
                        nargs=1)
    parser.add_argument('-l', '--log',
                        help="log via: stdout stderr syslog none (def: syslog)",
                        default="syslog",
                        action="store",
                        metavar='logtype',
                        type=str)
    parser.add_argument('-0', '--zero',
                        help="print None when user has no registered email (def: skip user)",
                        action='store_true')
    parser.add_argument('-u', '--username_args',
                        help="args are usernames (def: args are email addresses)",
                        action='store_true')
    parser.add_argument('-c', '--comma',
                        help="print comma between email and username (def: print tab)",
                        action='store_true')
    parser.add_argument('arg',
                        help="email (or usernane of -u)",
                        nargs="*")
    parser.add_argument('-L', '--level',
                        help="set log level: dbg debug info warn warning error crit critical (def: info)",
                        default="info",
                        action="store",
                        metavar='dbglvl',
                        type=str)
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

    # -s {e,u,eu} silence printing (def: print email and username)
    #
    #    e ==> email
    #    u ==> username
    #    eu ==> email and username
    #    ue ==> email and username
    #
    if args.silence:
        if args.silence[0] == 'e':
            print_email = False
        elif args.silence[0] == 'u':
            print_username = False
        elif args.silence[0] == 'eu' or args.silence[0] == 'ue':
            print_email = False
            print_username = False
        else:
            prerr(f'{program}: -e may only be followed by e, u, eu, or ue')
            sys.exit(4)

    # -0 - print None when user has no registered email
    #
    if args.zero:
        print_none = True

    # -u - args are usernames
    #
    if args.username_args:
        args_are_email = False

    # -c - print command (instead of tab) between the email and the username
    #
    if args.comma:
        print_comma = True

    # determine the number of optional args
    #
    argc = len(args.arg)

    # case: no args, process the entire submit server IOCCC password file
    #
    exit_code = 0
    if argc <= 0:

        # obtain the submit server IOCCC password file
        #
        pw_dict = read_pwfile()
        if not pw_dict:
            error(f'{program}: failed to load the submit server IOCCC password file')
            prerr(f'{program}: failed to load the submit server IOCCC password file')
            sys.exit(5)

        # print information from the entire submit server IOCCC password file
        #
        for i in pw_dict:

            # collect the username for this password entry
            #
            if 'username' in i:
                username = i['username']
            else:
                # malformed password entry as no username
                error(f'{program}: password entry number {i} has no username')
                continue
            if not isinstance(username, str):
                error(f'{program}: password entry number {i} username is not a string')
                continue

            # collect the email for this password entry
            #
            if 'email' in i:
                email = i['email']
            else:
                # malformed password entry as no username
                error(f'{program}: password entry number {i} has no email for username: {username}')
                continue

            # unless -0, ignore email that is None
            #
            if not print_none and not email:
                continue

            # convert None email to "None"
            #
            if not email:
                email = "None"

            # print information for this given password entry, if possible
            #
            if print_email and print_username:
                if print_comma:
                    print(f'{email},{username}')
                else:
                    print(f'{email}\t{username}')
            elif print_email:
                print(f'{email}')
            elif print_username:
                print(f'{username}')

    # case: process args
    #
    else:

        # process each arg
        #
        for i, arg in enumerate(args.arg):

            # case: process args w/o -u
            #
            # args are registered email address(es): determine the username
            #
            if args_are_email:

                # determine the username for this email address
                #
                email = arg
                username = lookup_username_by_email(email)

                # firewall - no user with this registered email address
                #
                if not username:
                    prerr(f'{program}: registered email address not found: {email}')
                    exit_code = 1
                    continue

            # case: process args with -u
            #
            # args are username(s), determine the registered email address
            #
            else:

                # firewall - verify username is valid
                #
                username = arg
                user_dict = lookup_username(username)
                if not user_dict:
                    prerr(f'{program}: username not found: {username}')
                    exit_code = 1
                    continue

                # determine the registered email address for this user
                #
                email = lookup_email_by_username(username)

            # unless -0, ignore email that is None
            #
            if not print_none and not email:
                prerr(f'{program}: no registered email address for username: {username}')
                exit_code = 1
                continue

            # convert None email to "None"
            #
            if not email:
                email = "None"

            # print information for this given password entry, if possible
            #
            if print_email and print_username:
                if print_comma:
                    print(f'{email},{username}')
                else:
                    print(f'{email}\t{username}')
            elif print_email:
                print(f'{email}')
            elif print_username:
                print(f'{username}')

    # All Done!!! All Done!!! -- Jessica Noll, Age 2
    #
    sys.exit(exit_code)
#
# pylint: enable=too-many-branches
# pylint: enable=too-many-statements
# pylint: enable=too-many-locals


# case: run from the command line
#
if __name__ == '__main__':
    main()
