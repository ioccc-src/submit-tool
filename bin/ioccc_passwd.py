#!/usr/bin/env python3
#
# ioccc_passwd.py - Manage IOCCC submit server accounts

"""
ioccc_passwd.py - Manage IOCCC submit server accounts

Functions to implement adding, updating and deleting of IOCCC contestants.
"""


# system imports
#
import sys
import argparse
import os
import uuid
import re


# import from modules
#
from datetime import datetime, timezone, timedelta


# import the ioccc python utility code
#
# Sort the import list with: sort -d -u
#
from iocccsubmit import \
        DEFAULT_GRACE_PERIOD, \
        change_startup_appdir, \
        delete_username, \
        error, \
        generate_password, \
        hash_password, \
        info, \
        lookup_username, \
        return_last_errmsg, \
        setup_logger, \
        update_username, \
        warning


# ioccc_passwd.py version
#
# NOTE: Use string of the form: "x.y[.z] YYYY-MM-DD"
#
VERSION = "2.4.0 2025-01-26"


# pylint: disable=too-many-locals
# pylint: disable=too-many-branches
# pylint: disable=too-many-statements
#
def main():
    """
    Main routine when run as a program.
    """

    # setup
    #
    force_pw_change = False
    password = None
    pwhash = None
    disable_login = False
    pw_change_by = None
    program = os.path.basename(__file__)
    ignore_date = False

    # parse args
    #
    parser = argparse.ArgumentParser(
                description="Manage IOCCC submit server accounts",
                epilog=f'{program} version: {VERSION}')
    parser.add_argument('-t', '--topdir',
                        help="app directory path",
                        metavar='appdir',
                        nargs=1)
    parser.add_argument('-a', '--add',
                        help="add a new user",
                        metavar='USER',
                        nargs=1)
    parser.add_argument('-u', '--update',
                        help="update a user or add if not a user",
                        metavar='USER',
                        nargs=1)
    parser.add_argument('-d', '--delete',
                        help="delete an exist user",
                        metavar='USER',
                        nargs=1)
    parser.add_argument('-p', '--password',
                        help="specify the password (def: generate random password)",
                        metavar='PW',
                        nargs=1)
    parser.add_argument('-c', '--change',
                        help='force a password change at next login',
                        action='store_true')
    parser.add_argument('-C', '--nochange',
                        help='clear the requirement to change password',
                        action='store_true')
    parser.add_argument('-g', '--grace',
                        help=f'grace seconds to change the password (def: {DEFAULT_GRACE_PERIOD})',
                        metavar='SECS',
                        type=int,
                        nargs=1)
    parser.add_argument('-n', '--nologin',
                        help='disable login (def: login not explicitly disabled)',
                        action='store_true')
    parser.add_argument('-I', '--ignore_date',
                        help='user may login when contest is closed (def: may not)',
                        action='store_true')
    parser.add_argument('-U', '--UUID',
                        help='generate a new UUID username and password',
                        action='store_true')
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
    args = parser.parse_args()

    # setup logging according to -l logtype -L dbglvl
    #
    setup_logger(args.log, args.level)

    # -t topdir - set the path to the top level app directory
    #
    if args.topdir:
        if not change_startup_appdir(args.topdir[0]):
            error(f'{program}: change_startup_appdir failed: {return_last_errmsg()}')
            print(f'{program}: change_startup_appdir failed: {return_last_errmsg()}')
            sys.exit(3)

    # -g secs - set the grace time to change in seconds from now
    #
    if args.grace:
        pw_change_by = re.sub(r'\+00:00 ', ' ',
                              f'{datetime.now(timezone.utc)+timedelta(seconds=args.grace[0])} UTC')

    # -c and -C conflict
    #
    if args.change and args.nochange:
        print("Notice via print: -C conflicts with -c")
        sys.exit(4)

    # -C and -g secs conflict
    #
    if args.grace and args.nochange:
        print("Notice via print: -C conflicts with -g secs")
        sys.exit(5)

    # -c - force user to change their password at the next login
    #
    if args.change:

        # require the password to change at first login
        #
        force_pw_change = True

        # case: -g not give, assume default grace period
        #
        if not args.grace:
            pw_change_by = re.sub(r'\+00:00 ', ' ',
                                  f'{datetime.now(timezone.utc)+timedelta(seconds=DEFAULT_GRACE_PERIOD)} UTC')

    # -C - disable password change at next login
    #
    if args.nochange:

        # require the password to change at first login
        #
        force_pw_change = False
        pw_change_by = None

    # -p password - use password supplied in the command line
    #
    if args.password:
        password = args.password[0]
        pwhash = hash_password(password)

    # -n - disable login of user
    #
    if args.nologin:
        disable_login = True

    # -I - allow user to ignore the date
    #
    if args.ignore_date:
        ignore_date = True

    # -a user - add user if they do not already exist
    #
    if args.add:

        # add with random password unless we used -p password
        #
        if not password:
            password = generate_password()

        # we store the hash of the password only
        #
        pwhash = hash_password(password)
        if not pwhash:
            error(f'{program}: -a user: hash_password for username: {username} failed: {return_last_errmsg()}')
            print(f'{program}: -a user: hash_password for username: {username} failed: {return_last_errmsg()}')
            sys.exit(4)

        # determine the username to add
        #
        username = args.add[0]

        # the user must not already exist
        #
        if lookup_username(username):
            warning(f'{program}: -a user: already exists for username: {username}')
            print(f'{program}: -a user: already exists for username: {username}')
            sys.exit(5)

        # add the user
        #
        if update_username(username, pwhash, ignore_date, force_pw_change, pw_change_by, disable_login):
            info(f'{program}: -a user: added username: {username}')
            print(f'{program}: -a user: added username: {username}')
            sys.exit(0)
        else:
            error(f'{program}: -a user: add username: {username} failed: {return_last_errmsg()}')
            print(f'{program}: -a user: add username: {username} failed: {return_last_errmsg()}')
            sys.exit(6)

    # -u user - update if they exit, or add user if they do not already exist
    #
    if args.update:

        # determine the username to update
        #
        username = args.update[0]

        # obtain the user_dict if the user exists
        #
        user_dict = lookup_username(username)

        # if this is an existing user, setup for the update
        #
        if user_dict:

            # case: -p was not given, keep the existing password hash
            #
            if not password:
                pwhash = user_dict['pwhash']

            # case: -I was not given, keep the existing ignore_date value
            #
            if not args.ignore_date:
                ignore_date = user_dict['ignore_date']

            # case: -c was not given, keep the existing force_pw_change
            #
            if not args.change:
                if not args.nochange:
                    force_pw_change = user_dict['force_pw_change']

            # case: -c nor -g was not given, keep the existing pw_change_by
            #
            if not pw_change_by:
                if not args.nochange:
                    pw_change_by = user_dict['pw_change_by']

            # case: -n was not given, keep the existing disable_login
            #
            if not args.nologin:
                disable_login = user_dict['disable_login']

        # if not yet a user, generate the random password unless we used -p password
        #
        else:

            # add with random password unless we used -p password
            #
            if not password:
                password = generate_password()

            # we store the hash of the password only
            #
            pwhash = hash_password(password)
            if not pwhash:
                error(f'{program}: -u user: hash_password for username: {username} failed: {return_last_errmsg()}')
                print(f'{program}: -u user: hash_password for username: {username} failed: {return_last_errmsg()}')
                sys.exit(7)

        # update the user
        #
        if update_username(username, pwhash, ignore_date, force_pw_change, pw_change_by, disable_login):
            if password:
                info(f'{program}: -u user: changed password for username: {username}')
                print(f'{program}: -u user: changed password for username: {username}')
            else:
                info(f'{program}: -u user: changed details for username: {username}')
                print(f'{program}: -u user: changed details for username: {username}')
            sys.exit(0)
        else:
            if password:
                error(f'{program}: -u user: failed to change password for username: {username} '
                      f'failed: {return_last_errmsg()}')
                print(f'{program}: -u user: failed to change password for username: {username} '
                      f'failed: {return_last_errmsg()}')
            else:
                error(f'{program}: -u user: failed to change details for username: {username} '
                      f'failed: {return_last_errmsg()}')
                print(f'{program}: -u user: failed to change details for username: {username} '
                      f'failed: {return_last_errmsg()}')
            sys.exit(8)

    # -d user - delete user
    #
    if args.delete:

        # determine the username to delete
        #
        username = args.delete[0]

        # the user must already exist
        #
        if not lookup_username(username):
            info(f'{program}: -d user: no such username: {username} last_errmsg: {return_last_errmsg()}')
            print(f'{program}: -d user: no such username: {username} last_errmsg: {return_last_errmsg()}')
            sys.exit(9)

        # remove the user
        #
        if delete_username(username):
            info(f'{program}: -d user: deleted username: {username} last_errmsg: {return_last_errmsg()}')
            print(f'{program}: -d user: deleted username: {username} last_errmsg: {return_last_errmsg()}')
            sys.exit(0)
        else:
            error(f'{program}: -d user: failed to delete username: {username} failed: {return_last_errmsg()}')
            print(f'{program}: -d user: failed to delete username: {username} failed: {return_last_errmsg()}')
            sys.exit(10)

    # -U - add random UUID user
    #
    if args.UUID:

        # add with random password unless we used -p password
        #
        if not password:
            password = generate_password()

        # we store the hash of the password only
        #
        pwhash = hash_password(password)
        if not pwhash:
            error(f'{program}: -U: hash_password failed: {return_last_errmsg()}')
            print(f'{program}: -U: hash_password failed: {return_last_errmsg()}')
            sys.exit(11)

        # generate an random UUID of type that is not an existing user
        #
        # We try a number of times until we find a new username, or
        # we give up trying.  More likely this loop will run only once
        # because the change of a duplicate UUID being found it nil.
        #
        username = None
        try_limit = 10
        for i in range(0, try_limit, 1):

            # try a new UUID
            #
            username = str(uuid.uuid4())

            # The IOCCC mkiocccentry(1) tool, version: 1.0.8 2024-08-23,
            # requires the UUID based username to be of this form:
            #
            #   xxxxxxxx-xxxx-4xxx-axxx-xxxxxxxxxxxx
            #
            # While str(uuid.uuid4()) does generate a '4' in the
            # 14th character postion, the 19th position seems
            # to be able to be any of [89ab].  We force the 19th
            # character position to be an 'a' for now.
            #
            tmp = list(username)
            # paranoia
            tmp[14] = '4'
            # mkiocccentry(1) tool, version: 1.0.8 2024-08-23 workaround
            tmp[19] = 'a'
            username = ''.join(tmp)

            # the user must not already exist
            #
            if not lookup_username(username):

                # new user was found
                #
                break

            # super rare case that we found an existing UUID, so try again
            #
            info(f'{program}: -U: rare: UUID retry {i+1} of {try_limit}')
            print(f'{program}: -U: rare: UUID retry {i+1} of {try_limit}')
            username = None

        # paranoia - no unique username was found
        #
        if not username:
            error(f'{program}: -U: SUPER RARE: failed to found a new UUID after {try_limit} attempts!!!')
            print(f'{program}: -U: SUPER RARE: failed to found a new UUID after {try_limit} attempts!!!')
            sys.exit(12)

        # add the user
        #
        if update_username(username, pwhash, ignore_date, force_pw_change, pw_change_by, disable_login):
            info(f'{program}: -U: added username: {username}')
            print(f'{program}: -U: added username: {username}')
            sys.exit(0)
        else:
            error(f'{program}: -U: add username: {username} failed: {return_last_errmsg()}')
            print(f'{program}: -U: add username: {username} failed: {return_last_errmsg()}')
            sys.exit(13)

    # no option selected
    #
    print(f'{program}: must use one of: -a USER or -u USER or -d USER or -U or -s DateTime or -S DateTime')
    sys.exit(14)
#
# pylint: enable=too-many-locals
# pylint: enable=too-many-branches
# pylint: enable=too-many-statements


# case: run from the command line
#
if __name__ == '__main__':
    main()
