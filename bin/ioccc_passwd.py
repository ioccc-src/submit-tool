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
import datetime

# import from modules
#
#from datetime import datetime, timezone, timedelta

# import the ioccc python utility code
#
# Sort the import list with: sort -d -u
#
from iocccsubmit import \
        change_startup_appdir, \
        DATETIME_USEC_FORMAT, \
        DEFAULT_GRACE_PERIOD, \
        delete_username, \
        error, \
        generate_password, \
        hash_password, \
        info, \
        lookup_username, \
        lookup_username_by_email, \
        prerr, \
        return_last_errmsg, \
        set_ioccc_locale, \
        setup_logger, \
        update_username, \
        warning


# ioccc_passwd.py version
#
# NOTE: Use string of the form: "x.y[.z] YYYY-MM-DD"
#
VERSION = "2.9.0 2025-04-20"


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
    email = None
    username_with_email = None
    output_for_email = False

    # IOCCC requires use of C locale
    #
    set_ioccc_locale()

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
    parser.add_argument('-P', '--changepw',
                        help="Generate new random user password, implies -E, requires -u USER",
                        action='store_true')
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
    parser.add_argument('-G', '--chgby',
                        help='set password change by date in "YYYY-MM-DD HH:MM:SS.micros UTC" format, implies -c',
                        metavar='DateTime',
                        type=str,
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
    parser.add_argument('-e', '--email',
                        help='set IOCCC email registration address',
                        metavar='EMAIL',
                        nargs=1)
    parser.add_argument('-E', '--email_output',
                        help='output data useful for sending account access email',
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
        now = datetime.datetime.now(datetime.timezone.utc)
        pw_change_by = re.sub(r'\+00:00 ', ' ',
                              f'{now+datetime.timedelta(seconds=args.grace[0])} UTC')

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

    # -P validation
    #
    if args.changepw:

        # -P and -p PW conflict
        #
        if args.password:
            print("Notice via print: -p PW conflicts with -P")
            sys.exit(6)

        # -P and -a USER conflict
        #
        if args.add:
            print("Notice via print: -a USER conflicts with -P")
            sys.exit(7)

        # -P and -d USER conflict
        #
        if args.delete:
            print("Notice via print: -d USER conflicts with -P")
            sys.exit(8)

        # -P and -U conflict
        #
        if args.UUID:
            print("Notice via print: -U conflicts with -P")
            sys.exit(9)

        # -P requires -u USER
        #
        if not args.update:
            print("Notice via print: -P requires use of -u USER")
            sys.exit(10)

        # -P implies -E
        #
        output_for_email = True

        # generate a new random password for user
        #
        password = generate_password()
        pwhash = hash_password(password)

    # -G DateTime processing
    #
    if args.chgby:

        # -G DateTime and -C conflict
        #
        if args.nochange:
            print("Notice via print: -G DateTime conflicts with -C")
            sys.exit(11)

        # -G DateTime and -g SECS
        #
        if args.grace:
            print("Notice via print: -G DateTime conflicts with -g SECS")
            sys.exit(12)

        # validate -G DateTime string
        #
        if not isinstance(args.chgby[0], str):
            print("Notice via print: -G DateTime must be a string in 'YYYY-MM-DD HH:MM:SS.micros UTC' format")
            sys.exit(13)
        try:
            dt = datetime.datetime.strptime(args.chgby[0], DATETIME_USEC_FORMAT)
        except ValueError:
            print("Notice via print: -G DateTime must be in 'YYYY-MM-DD HH:MM:SS.micros UTC' format")
            sys.exit(14)
        pw_change_by = re.sub(r'\+00:00 ', ' ', f'{dt} UTC')

        # -G DateTime implies -c
        #
        force_pw_change = True

    # -c - force user to change their password at the next login
    #
    if args.change:

        # require the password to change at first login
        #
        force_pw_change = True

        # case: -g not give, assume default grace period
        #
        if not args.grace:
            now = datetime.datetime.now(datetime.timezone.utc)
            pw_change_by = re.sub(r'\+00:00 ', ' ',
                                  f'{now+datetime.timedelta(seconds=DEFAULT_GRACE_PERIOD)} UTC')

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

    # -e email - set email registration address
    #
    if args.email:
        email = args.email[0]
        username_with_email = lookup_username_by_email(email)

    # -E - output data useful for sending account access email
    #
    if args.email_output:
        output_for_email = True

    # -a user - add user if they do not already exist
    #
    if args.add:

        # If we used -e email, but email is not already in use by another user
        #
        if username_with_email:
            error(f'{program}: -a user -e {email}: email address already used by: {username_with_email}')
            print(f'{program}: -a user -e {email}: email address already used by: {username_with_email}')
            sys.exit(15)

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
            sys.exit(16)

        # determine the username to add
        #
        username = args.add[0]

        # the user must not already exist
        #
        if lookup_username(username):
            warning(f'{program}: -a user: already exists for username: {username}')
            print(f'{program}: -a user: already exists for username: {username}')
            sys.exit(17)

        # add the user
        #
        if update_username(username, pwhash, ignore_date, force_pw_change, pw_change_by, email, disable_login):

            # case: -E output
            #
            if output_for_email:

                # firewall - with -E user MUST have an email address
                #
                user_dict = lookup_username(username)
                if not user_dict or not 'email' in user_dict or not isinstance(user_dict['email'], str):
                    error(f'{program}: -a user -E: while username: {username} as added, no email was set')
                    prerr(f'{program}: -a user -E: while username: {username} as added, no email was set')
                    sys.exit(18)

                # firewall - with -u user -E use of -p password is required
                #
                if not password or not isinstance(password, str):
                    error(f'{program}: -a user -E: while username: {username} as added, no password was set')
                    prerr(f'{program}: -a user -E: while username: {username} as added, no password was set')
                    sys.exit(19)

                # -E output
                #
                print(f'    username: {username}')
                print(f'    password: {password}')
                if force_pw_change:
                    print('')
                    print(f'    IMPORTANT: You MUST login and change your password before: {pw_change_by}')
                    info(f'{program}: -U: '
                         f'username: {username} '
                         f'email: {email} '
                         f'pw_change_by: {pw_change_by}')
                else:
                    info(f'{program}: -U: '
                         f'username: {username} '
                         f'email: {email}')
                sys.exit(0)

            # case: -e email output
            #
            elif args.email:
                if force_pw_change and pw_change_by:
                    info(f'{program}: -a user: '
                         f'username: {username} '
                         f'email: {email} '
                         f'pw_change_by: {pw_change_by}')
                    print(f'{program}: -a user: '
                          f'username: {username} '
                          f'email: {email} '
                          f'pw_change_by: {pw_change_by}')
                else:
                    info(f'{program}: -a user: '
                         f'username: {username} '
                         f'email: {email}')
                    print(f'{program}: -a user: '
                          f'username: {username} '
                          f'email: {email}')
                sys.exit(0)

            # case: output w/o -e nor -E
            #
            else:
                if force_pw_change and pw_change_by:
                    info(f'{program}: -a user: '
                         f'username: {username} '
                         f'pw_change_by: {pw_change_by}')
                    print(f'{program}: -a user: '
                          f'username: {username} '
                          f'pw_change_by: {pw_change_by}')
                else:
                    info(f'{program}: -a user: '
                         f'username: {username}')
                    print(f'{program}: -a user: '
                          f'username: {username}')
                sys.exit(0)

        # case: update_username failed for -a user
        #
        else:
            error(f'{program}: -a user: add username: {username} failed: {return_last_errmsg()}')
            print(f'{program}: -a user: add username: {username} failed: {return_last_errmsg()}')
            sys.exit(20)

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

            # If we used -e email, but email is not already in use by a different user
            #
            if args.email and username_with_email and username_with_email != username:
                error(f'{program}: -u {username} -e {email}: email address already used by: {username_with_email}')
                print(f'{program}: -u {username} -e {email}: email address already used by: {username_with_email}')
                sys.exit(21)

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

            # case: -e email was not given, keep the existing email
            #
            if not args.email:
                email = user_dict['email']

        # if not yet a user, generate the random password unless we used -p password
        #
        else:

            # If we used -e email, but email is not already in use by another user
            #
            if username_with_email:
                error(f'{program}: -a user -e {email}: email address already used by: {username_with_email}')
                print(f'{program}: -a user -e {email}: email address already used by: {username_with_email}')
                sys.exit(22)

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
                sys.exit(23)

        # update the user
        #
        if update_username(username, pwhash, ignore_date, force_pw_change, pw_change_by, email, disable_login):

            # case: -E output
            #
            if output_for_email:

                # firewall - with -E user MUST have an email address
                #
                user_dict = lookup_username(username)
                if not user_dict or not 'email' in user_dict or not isinstance(user_dict['email'], str):
                    error(f'{program}: -u user -E: while username: {username} as updated, no email was set')
                    prerr(f'{program}: -u user -E: while username: {username} as updated, no email was set')
                    sys.exit(24)

                # firewall - with -u user -E use of -p password is required
                #
                if not password or not isinstance(password, str):
                    error(f'{program}: -u user -E: while username: {username} as updated, no password was set')
                    prerr(f'{program}: -u user -E: while username: {username} as updated, no password was set')
                    sys.exit(25)

                # -E output
                #
                print(f'    username: {username}')
                print(f'    password: {password}')
                if force_pw_change:
                    print('')
                    print(f'    IMPORTANT: You MUST login and change your password before: {pw_change_by}')
                    info(f'{program}: -U: '
                         f'username: {username} '
                         f'email: {email} '
                         f'pw_change_by: {pw_change_by}')
                else:
                    info(f'{program}: -U: '
                         f'username: {username} '
                         f'email: {email}')
                sys.exit(0)

            # case: -e email output
            #
            elif args.email:
                if password:
                    if force_pw_change and pw_change_by:
                        info(f'{program}: -u user: changed password for '
                             f'username: {username} '
                             f'email: {email} '
                             f'pw_change_by: {pw_change_by}')
                        print(f'{program}: -u user: changed password for '
                              f'username: {username} '
                              f'email: {email} '
                              f'pw_change_by: {pw_change_by}')
                    else:
                        info(f'{program}: -u user: changed password for '
                             f'username: {username} '
                             f'email: {email}')
                        print(f'{program}: -u user: changed password for '
                              f'username: {username} '
                              f'email: {email}')
                else:
                    if force_pw_change and pw_change_by:
                        info(f'{program}: -u user: changed details for '
                             f'username: {username} '
                             f'email: {email} '
                             f'pw_change_by: {pw_change_by}')
                        print(f'{program}: -u user: changed details for '
                              f'username: {username} '
                              f'email: {email} '
                              f'pw_change_by: {pw_change_by}')
                    else:
                        info(f'{program}: -u user: changed details for '
                             f'username: {username} '
                             f'email: {email}')
                        print(f'{program}: -u user: changed details for '
                              f'username: {username} '
                              f'email: {email}')
                sys.exit(0)

            # case: output w/o -e nor -E
            #
            else:
                if password:
                    if force_pw_change and pw_change_by:
                        info(f'{program}: -u user: changed password for '
                             f'username: {username} '
                             f'pw_change_by: {pw_change_by}')
                        print(f'{program}: -u user: changed password for '
                              f'username: {username} '
                              f'pw_change_by: {pw_change_by}')
                    else:
                        info(f'{program}: -u user: changed password for '
                             f'username: {username}')
                        print(f'{program}: -u user: changed password for '
                              f'username: {username}')
                else:
                    if force_pw_change and pw_change_by:
                        info(f'{program}: -u user: changed details for '
                             f'username: {username} '
                             f'pw_change_by: {pw_change_by}')
                        print(f'{program}: -u user: changed details for '
                              f'username: {username} '
                              f'pw_change_by: {pw_change_by}')
                    else:
                        info(f'{program}: -u user: changed details for '
                             f'username: {username}')
                        print(f'{program}: -u user: changed details for '
                              f'username: {username}')
                sys.exit(0)

        # case: update_username failed for -u user
        #
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
            sys.exit(26)

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
            sys.exit(27)

        # remove the user
        #
        if delete_username(username):
            info(f'{program}: -d user: deleted '
                 f'username: {username}')
            print(f'{program}: -d user: deleted '
                  f'username: {username}')
            sys.exit(0)
        else:
            error(f'{program}: -d user: failed to delete username: {username} failed: {return_last_errmsg()}')
            print(f'{program}: -d user: failed to delete username: {username} failed: {return_last_errmsg()}')
            sys.exit(28)

    # -U - add random UUID user
    #
    if args.UUID:

        # If we used -e email, but email is not already in use by another user
        #
        if username_with_email:
            error(f'{program}: -a user -e {email}: email address already used by: {username_with_email}')
            print(f'{program}: -a user -e {email}: email address already used by: {username_with_email}')
            sys.exit(29)

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
            sys.exit(30)

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
            sys.exit(31)

        # add the user
        #
        if update_username(username, pwhash, ignore_date, force_pw_change, pw_change_by, email, disable_login):

            # case: -E output
            #
            if output_for_email:

                # firewall - with -E user MUST have an email address
                #
                user_dict = lookup_username(username)
                if not user_dict or not 'email' in user_dict or not isinstance(user_dict['email'], str):
                    error(f'{program}: -U -E: while username: {username} as created, no email was set')
                    prerr(f'{program}: -U -E: while username: {username} as created, no email was set')
                    sys.exit(32)

                # firewall - with -U -E use of -p password is required
                #
                if not password or not isinstance(password, str):
                    error(f'{program}: -U -E: while username: {username} as created, no password was set')
                    prerr(f'{program}: -U -E: while username: {username} as created, no password was set')
                    sys.exit(33)

                # -E output
                #
                print(f'    username: {username}')
                print(f'    password: {password}')
                if force_pw_change:
                    print('')
                    print(f'    IMPORTANT: You MUST login and change your password before: {pw_change_by}')
                    info(f'{program}: -U: '
                         f'username: {username} '
                         f'email: {email} '
                         f'pw_change_by: {pw_change_by}')
                else:
                    info(f'{program}: -U: '
                         f'username: {username} '
                         f'email: {email}')
                sys.exit(0)

            # case: -e email output
            #
            elif args.email:
                if force_pw_change and pw_change_by:
                    info(f'{program}: -U: '
                         f'username: {username} '
                         f'email: {email} '
                         f'pw_change_by: {pw_change_by}')
                    print(f'{program}: -U: '
                          f'username: {username} '
                          f'email: {email} '
                          f'pw_change_by: {pw_change_by}')
                else:
                    info(f'{program}: -U: '
                         f'username: {username} '
                         f'email: {email}')
                    print(f'{program}: -U: '
                          f'username: {username} '
                          f'email: {email}')

            # case: output w/o -e nor -E
            #
            else:
                if force_pw_change and pw_change_by:
                    info(f'{program}: -U: '
                         f'username: {username} '
                         f'pw_change_by: {pw_change_by}')
                    print(f'{program}: -U: '
                          f'username: {username} '
                          f'pw_change_by: {pw_change_by}')
                else:
                    info(f'{program}: -U: '
                         f'username: {username}')
                    print(f'{program}: -U: '
                          f'username: {username}')
            sys.exit(0)

        # case: update_username failed for -U
        #
        else:
            error(f'{program}: -U: add username: {username} failed: {return_last_errmsg()}')
            print(f'{program}: -U: add username: {username} failed: {return_last_errmsg()}')
            sys.exit(34)

    # no option selected
    #
    print(f'{program}: must use one of: -a USER or -u USER or -d USER or -U')
    sys.exit(35)
#
# pylint: enable=too-many-locals
# pylint: enable=too-many-branches
# pylint: enable=too-many-statements


# case: run from the command line
#
if __name__ == '__main__':
    main()
