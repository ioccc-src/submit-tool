#!/usr/bin/env python3
#
# chk_passwd.py - check if a password is Pwned

"""
chk_passwd.py - check if a password is Pwned using a local pwned password database

This is a test tool that uses the is_pw_pwned(password) python function from iocccsubmit.
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
        generate_password, \
        is_pw_pwned, \
        set_ioccc_locale


# chk_passwd.py version
#
# NOTE: Use string of the form: "x.y[.z] YYYY-MM-DD"
#
VERSION = "2.0.0 2025-12-05"


# pylint: disable=too-many-branches
# pylint: disable=too-many-statements
#
def main():
    """
    Main routine when run as a program.
    """

    # setup
    #
    password = None
    program = os.path.basename(__file__)
    pwned = None
    exit_code = 0
    silence_pwnage = False
    silence_non_pwnage = False
    pwned_count = 0
    non_pwned_count = 0
    quiet = False

    # IOCCC requires use of C locale
    #
    set_ioccc_locale()

    # parse args
    #
    parser = argparse.ArgumentParser(
                description="Check if passwords are pwned",
                epilog=f'{program} version: {VERSION}')
    parser.add_argument('-g', '--generate_pw',
                        help="test generated password(s) instead processing args",
                        action='store_true')
    parser.add_argument('-c', '--gen_count',
                        help='number of generated password(s) to test (def: 1)',
                        default=1,
                        action="store",
                        metavar='gen_count',
                        type=int)
    parser.add_argument('-s', '--silence_pwned_pw',
                        help="silence messages about pwned passwords",
                        action='store_true')
    parser.add_argument('-S', '--silence_non_pwned_pw',
                        help="silence messages about passwords without evidence that they are pwned",
                        action='store_true')
    parser.add_argument('-q', '--quiet',
                        help="quiet the final stats",
                        action='store_true')
    parser.add_argument('arg',
                        help="test args as passwords, unless -g no args ==> read passwords from stdin",
                        nargs="*")
    args = parser.parse_args()

    # determine the number of optional args
    #
    argc = len(args.arg)

    # -s - silence pwned passwords
    #
    if args.silence_pwned_pw:
        silence_pwnage = True

    # -S - silence passwords without evidence that they are pwned
    #
    if args.silence_non_pwned_pw:
        silence_non_pwnage = True

    # -q - silence printing of final stats
    #
    if args.quiet:
        quiet = True

    # -g - generate password instead of processing args
    #
    if args.generate_pw:
        for i in range(0, args.gen_count, 1):
            password = generate_password()
            pwned = is_pw_pwned(password)
            if pwned:
                if not silence_pwnage:
                    print(f'{program}: password[{i}] is pwned: {password}')
                pwned_count = pwned_count + 1
                exit_code = 1
            else:
                if not silence_non_pwnage:
                    print(f'{program}: no evidence of pwned password[{i}]: {password}')
                non_pwned_count = non_pwned_count + 1
            i = i + 1

    # case: no -g and args as passwords
    #
    else:
        if argc > 0:
            for i, arg in enumerate(args.arg):
                pwned = is_pw_pwned(arg)
                if pwned:
                    if not silence_pwnage:
                        print(f'{program}: password[{i}] is pwned: {arg}')
                    pwned_count = pwned_count + 1
                    exit_code = 1
                else:
                    if not silence_non_pwnage:
                        print(f'{program}: no evidence of a pwned password[{i}]: {arg}')
                    non_pwned_count = non_pwned_count + 1

        # case: no -g and read passwords from stdin
        #
        else:
            i = 0
            for line in sys.stdin:
                line = line.strip()
                pwned = is_pw_pwned(line)
                if pwned:
                    if not silence_pwnage:
                        print(f'{program}: stdin password[{i}] is pwned: {line}')
                    pwned_count = pwned_count + 1
                    exit_code = 1
                else:
                    if not silence_non_pwnage:
                        print(f'{program}: no evidence of a pwned stdin password[{i}]: {line}')
                    non_pwned_count = non_pwned_count + 1
                i = i + 1

    # end of processing wrap up
    #
    if not quiet:
        print(f'{program}: password test count: {i}')
        print(f'{program}: pwned password count: {pwned_count}')
        print(f'{program}: no evidence of pwned password count: {non_pwned_count}')
    sys.exit(exit_code)
#
# pylint: enable=too-many-branches
# pylint: enable=too-many-statements

# case: run from the command line
#
if __name__ == '__main__':
    main()
