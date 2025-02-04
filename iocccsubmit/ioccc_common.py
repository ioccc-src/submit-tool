#!/usr/bin/env python3
#
# ioccc_common.py - Common functions used by the IOCCC Submit Server and bin related tools
#
# pylint: disable=too-many-lines

"""
ioccc_common.py - Common functions used by the IOCCC Submit Server and bin related tools

IMPORTANT NOTE: This code must NOT assume the use of Flask, nor call
                functions such as flash().  This code may be imported
                into utility functions that are command line and not
                web app related.

IMPORTANT NOTE: To return an error message to a caller, set: ioccc_last_errmsg
"""

# import modules
#
import sys
import re
import json
import os
import inspect
import string
import secrets
import random
import shutil
import hashlib
import uuid
import logging


# import from modules
#
from string import Template
from os import makedirs, umask
from datetime import datetime, timezone
from pathlib import Path
from random import randrange
from logging.handlers import SysLogHandler
from flask import request


# For user locking
#
# We use the python filelock module.  See:
#
#    https://pypi.org/project/filelock/
#    https://py-filelock.readthedocs.io/en/latest/api.html
#    https://snyk.io/advisor/python/filelock/example
#    https://witve.com/codes/comprehensive-guide-to-filelock-mastering-apis-with-examples/
#
from filelock import Timeout, FileLock


# 3rd party imports
#
from werkzeug.security import check_password_hash, generate_password_hash


##################
# Global constants
##################

# ioccc_common.py version
#
# NOTE: Use string of the form: "x.y[.z] YYYY-MM-DD"
#
VERSION_IOCCC_COMMON = "2.5.1 2025-02-03"

# force password change grace time
#
# Time in seconds from when force_pw_change is set to true that the
# user must login and change their password.
#
# If "force_pw_change" is "true", then login is denied if now > pw_change_by.
#
DEFAULT_GRACE_PERIOD = 72*3600

# standard date string in strptime format
#
# The date string produced by:
#
#   date_string = re.sub(r'\+00:00 ', ' ', f'{datetime.now(timezone.utc)} UTC')
#
# may be converted back into a datetime object by:
#
#   dt = datetime.strptime(date_string, DATETIME_USEC_FORMAT)
#
DATETIME_USEC_FORMAT = "%Y-%m-%d %H:%M:%S.%f UTC"

# IP and port when running this code from the command line.
#
# When this code be being run under Apache, the wsgi module takes
# care of the hostname and port and this these two settings do not apply.
#
IP_ADDRESS = "127.0.0.1"
TCP_PORT = "8191"

# determine the default APPDIR
#
# case: We have template sub-directory, assume our APPDIR is .
#       (likely testing from the command line)
#
if Path("./templates").is_dir():
    APPDIR = "."

# case: assume are are running under the Apache server, and
#       APPDIR is /var/ioccc
#
# Tests suggest that Apache seems to run applications from the / directory.
#
else:
    APPDIR = "/var/ioccc"

# important directories and files that are relative to APPDIR
#
# We set FOO_RELATIVE_PATH, the value relative to APPDIR, and
# then set FOO to be APPDIR + "/" + FOO_RELATIVE_PATH.
#
# IMPORTANT NOTE: Calling change_startup_appdir(topdir) can
#                 change APPDIR and all of the values below
#                 that depend on APPDIR.
#
PW_FILE_RELATIVE_PATH = "etc/iocccpasswd.json"
PW_FILE = f'{APPDIR}/{PW_FILE_RELATIVE_PATH}'
#
INIT_PW_FILE_RELATIVE_PATH = "etc/init.iocccpasswd.json"
INIT_PW_FILE = f'{APPDIR}/{INIT_PW_FILE_RELATIVE_PATH}'
#
PW_LOCK_RELATIVE_PATH = "etc/iocccpasswd.lock"
PW_LOCK = f'{APPDIR}/{PW_LOCK_RELATIVE_PATH}'
#
ADM_FILE_RELATIVE_PATH = "etc/admins.json"
ADM_FILE = f'{APPDIR}/{ADM_FILE_RELATIVE_PATH}'
#
SECRET_FILE_RELATIVE_PATH = "etc/.secret"
SECRET_FILE = f'{APPDIR}/{SECRET_FILE_RELATIVE_PATH}'
#
USERS_DIR_RELATIVE_PATH = "users"
USERS_DIR = f'{APPDIR}/{USERS_DIR_RELATIVE_PATH}'
#
STATE_FILE_RELATIVE_PATH = "etc/state.json"
STATE_FILE = f'{APPDIR}/{STATE_FILE_RELATIVE_PATH}'
#
INIT_STATE_FILE_RELATIVE_PATH = "etc/init.state.json"
INIT_STATE_FILE = f'{APPDIR}/{INIT_STATE_FILE_RELATIVE_PATH}'
#
STATE_FILE_LOCK_RELATIVE_PATH = "etc/state.lock"
STATE_FILE_LOCK = f'{APPDIR}/{STATE_FILE_LOCK_RELATIVE_PATH}'
#
PW_WORDS_RELATIVE_PATH = "etc/pw.words"
PW_WORDS = f'{APPDIR}/{PW_WORDS_RELATIVE_PATH}'

# minimum SECRET length in characters
#
MIN_SECRET_LEN = 15

# POSIX safe filename regular expression
#
POSIX_SAFE_RE = "^[0-9A-Za-z][0-9A-Za-z._+-]*$"

# slot dictionary for slot JSON file
#
NO_COMMENT_VALUE = "mandatory comment: because comments were removed from the original JSON spec"
SLOT_VERSION_VALUE = "1.2 2025-01-26"
EMPTY_JSON_SLOT_TEMPLATE = '''{
    "no_comment": "$NO_COMMENT_VALUE",
    "slot_JSON_format_version":  "$SLOT_VERSION_VALUE",
    "slot": $slot_num,
    "filename": null,
    "length": null,
    "date": null,
    "SHA256": null,
    "collected": false,
    "status": "slot is empty"
}'''


# username rules
#
# NOTE: UUID usernames are 36 characters, however
#       templates/login.html can hold 40 (maybe 41) characters in username before scrolling
#       We put the maximum at 40 for the above reasons (excuses)
#
# NOTE: We put the minimum at 1 out of paranoia about empty strings.
#
MIN_USERNAME_LENGTH = 1
MAX_USERNAME_LENGTH = 40

# password related JSON values
#
PASSWORD_VERSION_VALUE = "1.2 2025-01-26"

# state (open and close) related JSON values
#
STATE_VERSION_VALUE = "1.2 2025-01-26"
DEFAULT_JSON_STATE_TEMPLATE = '''{
    "no_comment": "$NO_COMMENT_VALUE",
    "state_JSON_format_version": "$STATE_VERSION_VALUE",
    "open_date": "$OPEN_DATE",
    "close_date": "$CLOSE_DATE"
}'''

# password rules
#
# For password rule guidance, see:
#
#    https://pages.nist.gov/800-63-4/sp800-63b.html
#    https://cybersecuritynews.com/nist-rules-password-security/
#
# NOTE: templates/login.html can hold 40 (maybe 41) characters in password before scrolling
#       We put the maximum at 40 for the above reasons (excuses)
#
MIN_PASSWORD_LENGTH = 15
MAX_PASSWORD_LENGTH = 40

# Full path of the startup current working directory
#
STARTUP_CWD = os.getcwd()

# determine the default Pwned password tree
#
# If we have a pwned.pw.tree directory (or symlink to a directory) under the current
# working directory (i.e., "." but using the full path).
#
if Path(f"{STARTUP_CWD}/pwned.pw.tree").is_dir():
    PWNED_PW_TREE = f"{STARTUP_CWD}/pwned.pw.tree"

# Otherwise if we have a pwned.pw.tree directory (or symlink to a directory) under APPDIR,
# then use that as Pwned password tree.
#
elif Path(f"{APPDIR}/pwned.pw.tree").is_dir():
    PWNED_PW_TREE = f"{APPDIR}/pwned.pw.tree"

# Assume the system default Pwned password
#
# This tree was downloaded by:
#
#   /usr/local/bin/pwned-pw-download /usr/local/share/pwned.pw.tree
#
# where /usr/local/bin/pwned-pw-download was installed from:
#
#   https://github.com/lcn2/pwned-pw-download
#
else:
    PWNED_PW_TREE = "/usr/local/share/pwned.pw.tree"

# length of a SHA1 hash in ASCII hex characters
#
SHA1_HEXLEN = 40

# length of a SHA256 hash in ASCII hex characters
#
SHA256_HEXLEN = 64

# SHA256 buffer size
#
# Used by sha256_file(), and is selected to be about 20 4K memory pages.
#
SHA25_BUFSIZE= 20*4096

# slot numbers from 0 to MAX_SUBMIT_SLOT
#
# IMPORTANT:
#
# The MAX_SUBMIT_SLOT must match MAX_SUBMIT_SLOT define found in this file
#
#   soup/limit_ioccc.h
#
# from the mkiocccentry GitHub repo.  See:
#
#   https://github.com/ioccc-src/mkiocccentry/blob/master/soup/limit_ioccc.h
#
MAX_SUBMIT_SLOT = 9

# compressed tarball size limit in bytes
#
# IMPORTANT:
#
# The MAX_TARBALL_LEN must match MAX_TARBALL_LEN define found in this file
#
#   soup/limit_ioccc.h
#
# from the mkiocccentry GitHub repo.  See:
#
#   https://github.com/ioccc-src/mkiocccentry/blob/master/soup/limit_ioccc.h
#
MAX_TARBALL_LEN = 3999971

# where to stage submit files exporting (remote collection)
#
STAGED_DIR = f'{APPDIR}/staged'

# lock state - lock file descriptor or none
#
# NOTE: See the URLs listed under "For user locking" of the "from from filelock import" above.
#
# When ioccc_last_lock_fd is not none, flock is holding a lock on the file ioccc_last_lock_path.
# When ioccc_last_lock_fd is none, no flock is currently being held.
#
# When we try lock a file via ioccc_file_lock() and we are holding a lock on another file,
# we will force the flock to be released.
#
# The lock file only needs to be locked during a brief operation,
# which are brief in duration.  Moreover this server is NOT multi-threaded.
# We NEVER want to lock more than one file at a time.
#
# Nevertheless if, before we start, say. a slot operation AND before we attempt
# to lock the slot lock file, we discover that some other file is still locked
# (due to unexpected asynchronous event or exception, or code bug), we
# will force that previous lock to be unlocked.
#
# pylint: disable-next=global-statement,invalid-name
ioccc_last_lock_fd = None         # lock file descriptor, or None
# pylint: disable-next=global-statement,invalid-name
ioccc_last_lock_path = None       # path of the file that is locked, or None
# pylint: disable-next=global-statement,invalid-name
ioccc_last_errmsg = ""            # recent error message or empty string
# pylint: disable-next=global-statement,invalid-name
ioccc_pw_words = []

# Lock parameters
#
LOCK_TIMEOUT = 13                           # lock timeout in seconds
LOCK_INTERVAL = random.uniform(0.8, 1.2)    # poll for lock at interval 0.8 <= seconds <= 1.2

# IOCCC logger - how we log events
#
# When ioccc_logger is None, no logging is performed,
# otherwise ioccc_logger is a logging facility setup via setup_logger(string).
#
# NOTE: Until setup_logger(Bool) is called, ioccc_logger is None,
#       and no logging will occur.
#
# pylint: disable-next=invalid-name
ioccc_logger = None


def return_last_errmsg():
    """
    Return the recent error message or empty string

    Returns:
        ioccc_last_errmsg as a string
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # paranoia - if ioccc_last_errmsg is not a string, return as string version
    #
    if not isinstance(ioccc_last_errmsg, str):
        ioccc_last_errmsg = str(ioccc_last_errmsg)

    # return string
    #
    return ioccc_last_errmsg


def return_client_ip() -> str:
    """
    Return the client IP address or ((UNKNOWN))
    """

    # setup
    #
    me = inspect.currentframe().f_code.co_name
    ip = "((UNKNOWN))"

    # paranoia - handle if we do not have a request
    #
    if not request:
        debug(f'{me}: we do not have a request')

    # paranoia - handle if we do not have request headers
    #
    elif not request.headers:
        debug(f'{me}: we have no request.headers')

    # case: IP address from request headers
    #
    elif 'X-Forwarded-For' in request.headers:
        debug(f'{me}: we have X-Forwarded-For for IP address')
        ip = request.headers['X-Forwarded-For'].split(',')[0]

    elif 'HTTP_X_FORWARDED_FOR' in request.headers:
        debug(f'{me}: we have HTTP_X_FORWARDED_FOR for IP address')
        ip = request.headers['HTTP_X_FORWARDED_FOR'].split(',')[0]

    elif 'REMOTE_ADDR' in request.headers:
        debug(f'{me}: we have REMOTE_ADDR for IP address')
        ip = request.headers['REMOTE_ADDR'].split(',')[0]

    # case: IP address from request
    #
    else:
        debug(f'{me}: hoping request.remote_addr will provide IP address')
        ip = request.remote_addr

    # paranoia - if we don't have an ip address string
    #
    if not isinstance(ip, str):
        debug(f'{me}: ip value is not a string')

    # paranoia - if we ip address string is empty
    #
    elif len(ip) <= 0:
        debug(f'{me}: ip value is an empty string')

    # all is OK - we hope
    #
    else:
        debug(f'{me}: client IP address: {ip}')
        # fall thru

    # return ip address or "((UNKNOWN))"
    #
    return ip


def change_startup_appdir(topdir):
    """
    Change the path to the app directory from the APPDIR default.
    Modify paths to all other files and directories used in this file.

    NOTE: It is important that this function be called early AND
          before other functions in this file that use directories
          and files, are called.  Calling this function after other functions
          are called could lead to unpredictable and undesirable results!

    Given:
        topdir  path to the app directory

    Returns:
        True ==> paths successfully changed
        False ==> app directory not found, or
                  topdir is not a string argument
    """

    # setup
    #
    # pylint: disable=global-statement
    global ioccc_last_errmsg
    global APPDIR
    global PW_FILE
    global INIT_PW_FILE
    global PW_LOCK
    global ADM_FILE
    global SECRET_FILE
    global USERS_DIR
    global STATE_FILE
    global INIT_STATE_FILE
    global STATE_FILE_LOCK
    global PW_WORDS
    global STAGED_DIR
    # pylint: enable=global-statement
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # paranoia - if ioccc_last_errmsg is not a string, return as string version
    #
    if not isinstance(topdir, str):
        ioccc_last_errmsg = f'ERROR: {me}: topdir arg is not a string'
        error(f'{me}: topdir arg is not a string')
        return False

    # topdir must be a directory
    #
    if not Path(topdir).is_dir():
        ioccc_last_errmsg = f'ERROR: {me}: topdir is not a directory: {topdir}'
        error(f'{me}: topdir arg is not a directory')
        return False

    # now modify paths to all other files and directories used in this file
    #
    # pylint: disable=redefined-outer-name
    #
    APPDIR = topdir
    #
    PW_FILE = f'{topdir}/{PW_FILE_RELATIVE_PATH}'
    INIT_PW_FILE = f'{topdir}/{INIT_PW_FILE_RELATIVE_PATH}'
    PW_LOCK = f'{topdir}/{PW_LOCK_RELATIVE_PATH}'
    ADM_FILE = f'{topdir}/{ADM_FILE_RELATIVE_PATH}'
    SECRET_FILE = f'{topdir}/{SECRET_FILE_RELATIVE_PATH}'
    USERS_DIR = f'{topdir}/{USERS_DIR_RELATIVE_PATH}'
    STATE_FILE = f'{topdir}/{STATE_FILE_RELATIVE_PATH}'
    INIT_STATE_FILE = f'{topdir}/{INIT_STATE_FILE_RELATIVE_PATH}'
    STATE_FILE_LOCK = f'{topdir}/{STATE_FILE_LOCK_RELATIVE_PATH}'
    PW_WORDS = f'{topdir}/{PW_WORDS_RELATIVE_PATH}'
    STAGED_DIR = f'{APPDIR}/staged'
    #
    # pylint: enable=redefined-outer-name

    # assume all is well
    #
    debug(f'{me}: end')
    return True


def check_username_arg(username):
    """
    Determine if the username passes various sanity checks:

        0) username arg must be a string
        1) username cannot be too short
        2) username cannot be too long
        3) username must be a POSIX safe filename string

    Given:
        username    IOCCC submit server username

    Returns:
        True ==> username passes all of the canonical firewall checks
        False ==> username fails at least one of the canonical firewall checks

    NOTE: This function performs various canonical firewall checks on the username arg.
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    # We do NOT want to call debug from this function because we call this code too frequently
    #no#debug(f'{me}: start')

    # firewall - username arg must be a string
    #
    # NOTE: From the wsgi/ioccc.wsgi web application, a non-string
    #       username most likely comes from something like a system cracker
    #       playing with the login page via bogus POST HTTP action.
    #
    # NOTE: When testing with the bin/ioccc_submit.py test tool,
    #       this firewall test may also be triggered.
    #
    # NOTE: In all other cases, failing this firewall is unexpected.
    #
    if not isinstance(username, str):
        ioccc_last_errmsg = f'ERROR: {me}: username arg is not a string'
        # use info() instead of error() - cause may be a system cracked or testing.
        info(f'{me}: username arg is not a string')
        return False

    # firewall - username cannot be empty
    #
    # NOTE: From the wsgi/ioccc.wsgi web application, a non-string
    #       username most likely comes from something like a system cracker
    #       playing with the login page via bogus POST HTTP action.
    #
    # NOTE: When testing with the bin/ioccc_submit.py test tool,
    #       this firewall test may also be triggered.
    #
    # NOTE: In all other cases, failing this firewall is unexpected.
    #
    if len(username) == 0:
        ioccc_last_errmsg = f'ERROR: {me}: username is missing'
        # use info() instead of error() - cause may be a system cracked or testing.
        info(f'{me}: username is missing')
        return False

    # firewall - username cannot be too short
    #
    # NOTE: From the wsgi/ioccc.wsgi web application, a non-string
    #       username most likely comes from something like a system cracker
    #       playing with the login page via bogus POST HTTP action.
    #
    # NOTE: When testing with the bin/ioccc_submit.py test tool,
    #       this firewall test may also be triggered.
    #
    # NOTE: In all other cases, failing this firewall is unexpected.
    #
    if len(username) < MIN_USERNAME_LENGTH:
        ioccc_last_errmsg = f'ERROR: {me}: username arg is too short: {len(username)} < {MIN_USERNAME_LENGTH}'
        # use info() instead of error() - cause may be a system cracked or testing.
        info(f'{me}: username arg is too short: {len(username)} < {MIN_USERNAME_LENGTH}')
        return False

    # firewall - username cannot be too long
    #
    # NOTE: From the wsgi/ioccc.wsgi web application, a non-string
    #       username most likely comes from something like a system cracker
    #       playing with the login page via bogus POST HTTP action.
    #
    # NOTE: When testing with the bin/ioccc_submit.py test tool,
    #       this firewall test may also be triggered.
    #
    # NOTE: In all other cases, failing this firewall is unexpected.
    #
    if len(username) > MAX_USERNAME_LENGTH:
        ioccc_last_errmsg = f'ERROR: {me}: username arg is too long: {len(username)} > {MAX_USERNAME_LENGTH}'
        # use info() instead of error() - cause may be a system cracked or testing.
        info(f'{me}: username arg is too long: {len(username)} > {MAX_USERNAME_LENGTH}')
        return False

    # firewall - username must be a POSIX safe filename string
    #
    # NOTE: From the wsgi/ioccc.wsgi web application, a non-string
    #       username most likely comes from something like a system cracker
    #       playing with the login page via bogus POST HTTP action.
    #
    # NOTE: When testing with the bin/ioccc_submit.py test tool,
    #       this firewall test may also be triggered.
    #
    # NOTE: In all other cases, failing this firewall is unexpected.
    #
    if not re.match(POSIX_SAFE_RE, username):
        ioccc_last_errmsg = f'ERROR: {me}: username arg not POSIX safe'
        # use info() instead of error() - cause may be a system cracked or testing.
        info(f'{me}: username arg not POSIX safe')
        return False

    # username passes all of the canonical firewall checks
    #
    # We do NOT want to call debug from this function because we call this code too frequently
    #no#debug(f'{me}: end: valid username: {username}')
    return True


def check_slot_num_arg(slot_num):
    """
    Determine if the slot number passes various sanity checks:

        0) slot_num arg must be an int
        1) 0 <= slot_num <= MAX_SUBMIT_SLOT

    Given:
        slot_num    slot number

    Returns:
        True ==> slot_num passes all of the canonical firewall checks
        False ==> slot_num fails at least one of the canonical firewall checks

    NOTE: This function performs various canonical firewall checks on the slot_num arg.
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    # We do NOT want to call debug from this function because we call this code too frequently
    #no#debug(f'{me}: start')

    # firewall - slot_num arg must be an integer
    #
    if not isinstance(slot_num, int):
        ioccc_last_errmsg = f'ERROR: {me}: slot_num arg is not an int'
        error(f'{me}: slot_num arg is not an int')
        return False

    # firewall - must be a valid slot number
    #
    if (slot_num < 0 or slot_num > MAX_SUBMIT_SLOT):
        ioccc_last_errmsg = f'ERROR: {me}: invalid slot number: {slot_num}'
        error(f'{me}: invalid slot number: {slot_num}')
        return False

    # username passes all of the canonical firewall checks
    #
    # We do NOT want to call debug from this function because we call this code too frequently
    #no#debug(f'{me}: end: valid slot_num: {slot_num}')
    return True


def return_user_dir_path(username):
    """
    Return the user directory path

    Given:
        username    IOCCC submit server username

    Returns:
        None ==> username is not POSIX safe
        != None ==> user directory path (which may not yet exist) for a user (which not yet exist)

    NOTE: This function performs various canonical firewall checks on the username arg.

    NOTE: A useful side effect of this call is to verify that the username
          string is sane.  However, the username may not be a valid user
          nor may the user directory exist.  It is up to caller to check that.

    NOTE: It is up the caller to create, if needed, the user directory.
    """

    # setup
    #
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - canonical firewall checks on the username arg
    #
    if not check_username_arg(username):

        # The check_username_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a username firewall check failure.
        #
        return None

    # return user directory path
    #
    user_dir = f'{USERS_DIR}/{username}'
    debug(f'{me}: end: returning user_dir: {user_dir}')
    return user_dir


# pylint: disable=too-many-return-statements
#
def return_slot_dir_path(username, slot_num):
    """
    Return the slot directory path under a given user directory

    NOTE: This function performs various canonical firewall checks on the slot_num arg.

    Given:
        username    IOCCC submit server username
        slot_num    slot number for a given username

    Returns:
        None ==> invalid slot number or invalid user directory
        != None ==> slot directory path (may not yet exist)

    NOTE: This function performs various canonical firewall checks on the username arg.

    NOTE: This function performs various canonical firewall checks on the slot_num arg.

    It is up the caller to create, if needed, the slot directory.
    """

    # setup
    #
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - canonical firewall checks on the username arg
    #
    if not check_username_arg(username):

        # The check_username_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a username firewall check failure.
        #
        return None

    # firewall - canonical firewall checks on the slot_num arg
    #
    if not check_slot_num_arg(slot_num):

        # The check_slot_num_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a slot_num firewall check failure.
        #
        return None

    # determine user directory path
    #
    user_dir = return_user_dir_path(username)
    if not user_dir:
        error(f'{me}: return_user_dir_path failed for username: {username}')
        return None

    # return slot directory path under a given user directory
    #
    slot_dir = f'{user_dir}/{slot_num}'
    debug(f'{me}: end: returning slot_dir: {slot_dir}')
    return slot_dir
#
# pylint: enable=too-many-return-statements


# pylint: disable=too-many-return-statements
#
def return_slot_json_filename(username, slot_num):
    """
    Return the JSON filename for given slot directory of a given user directory

    Given:
        username    IOCCC submit server username
        slot_num    slot number for a given username

    Returns:
        None ==> invalid slot number or invalid user directory
        != None ==> path of the JSON filename for this user's slot (may not yet exist)

    NOTE: This function performs various canonical firewall checks on the username arg.

    NOTE: This function performs various canonical firewall checks on the slot_num arg.

    It is up the caller to create, if needed, the JSON filename.
    """

    # setup
    #
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - canonical firewall checks on the username arg
    #
    if not check_username_arg(username):

        # The check_username_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a username firewall check failure.
        #
        return None

    # firewall - canonical firewall checks on the slot_num arg
    #
    if not check_slot_num_arg(slot_num):

        # The check_slot_num_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a slot_num firewall check failure.
        #
        return None

    # determine user directory path
    #
    user_dir = return_user_dir_path(username)
    if not user_dir:
        error(f'{me}: return_user_dir_path failed for username: {username}')
        return None

    # determine slot directory path
    #
    slot_dir = return_slot_dir_path(username, slot_num)
    if not slot_dir:
        error(f'{me}: return_slot_dir_path failed for username: {username} slot_num: {slot_num}')
        return None

    # determine the JSON filename for this given slot
    #
    slot_json_file = f'{slot_dir}/slot.json'
    debug(f'{me}: end: returning slot_json_file: {slot_json_file}')
    return slot_json_file
#
# pylint: enable=too-many-return-statements


# pylint: disable=too-many-return-statements
#
def return_slot_lockfile(username, slot_num):
    """
    Return the JSON slot lock file.

    Given:
        username    IOCCC submit server username
        slot_num    slot number for a given username

    Returns:
        None ==> invalid slot number or invalid user directory
        != None ==> path of the JSON lock file for this user's slot (may not yet exist)

    NOTE: This function performs various canonical firewall checks on the username arg.

    NOTE: This function performs various canonical firewall checks on the slot_num arg.

    It is up the caller to create, if needed, the JSON lock file.
    """

    # setup
    #
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - canonical firewall checks on the username arg
    #
    if not check_username_arg(username):

        # The check_username_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a username firewall check failure.
        #
        return None

    # firewall - canonical firewall checks on the slot_num arg
    #
    if not check_slot_num_arg(slot_num):

        # The check_slot_num_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a slot_num firewall check failure.
        #
        return None

    # determine user directory path
    #
    user_dir = return_user_dir_path(username)
    if not user_dir:
        error(f'{me}: return_user_dir_path failed for username: {username}')
        return None

    # determine slot directory path
    #
    slot_dir = return_slot_dir_path(username, slot_num)
    if not slot_dir:
        error(f'{me}: return_slot_dir_path failed for username: {username} slot_num: {slot_num}')
        return None

    # determine the lock file for this given slot
    #
    slot_lockfile = f'{slot_dir}/lock'
    debug(f'{me}: end: returning slot_lockfile: {slot_lockfile}')
    return slot_lockfile
#
# pylint: enable=too-many-return-statements


# pylint: disable=too-many-return-statements
#
def return_submit_filename(slot_dict, username, slot_num):
    """
    Return the filename of the submit file as found in the JSON slot file.

    Given:
        slot_dict   slot JSON content as a python dictionary
        username    IOCCC submit server username
        slot_num    slot number for a given username

    Returns:
        != None ==> filename of the submit file in a slot
        None ==> no such submit file, or
                 bad args, or
                 no filename in slot JSON file

    NOTE: This function performs various canonical firewall checks on the username arg.

    NOTE: This function performs various canonical firewall checks on the slot_num arg.

    NOTE: The slot is not validated by this function.  The caller should validate the slot as needed.

    It is up the caller to create, if needed, the JSON lock file.
    """

    # setup
    #
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - canonical firewall checks on the username arg
    #
    if not check_username_arg(username):

        # The check_username_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a username firewall check failure.
        #
        return None

    # firewall - canonical firewall checks on the slot_num arg
    #
    if not check_slot_num_arg(slot_num):

        # The check_slot_num_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a slot_num firewall check failure.
        #
        return None

    # validate args
    #
    if not isinstance(slot_dict, dict):
        return 'slot_dict arg is not a python dictionary'

    # obtain path of the submit filename
    #
    if not 'filename' in slot_dict:
        error(f'{me}: submit filename missing from slot JSON file for username: {username} slot_num: {slot_num}')
        return None
    if not slot_dict['filename']:
        # no submit file has ever been uploaded to this slot
        return None
    if not isinstance(slot_dict['filename'], str):
        error(f'{me}: submit filename is not a string for username: {username} slot_num: {slot_num}')
        return None

    # return submit filename
    #
    submit_file = slot_dict["filename"]
    debug(f'{me}: end: returning submit_file: {submit_file}')
    return submit_file
#
# pylint: enable=too-many-return-statements


# pylint: disable=too-many-return-statements
#
def return_submit_path(slot_dict, username, slot_num):
    """
    Return the path of the submit file.

    Given:
        slot_dict   slot JSON content as a python dictionary
        username    IOCCC submit server username
        slot_num    slot number for a given username

    Returns:
        != None ==> path of the submit file in a slot
        None ==> no such submit file, or
                 bad args, or
                 no filename in slot JSON file

    NOTE: This function performs various canonical firewall checks on the username arg.

    NOTE: This function performs various canonical firewall checks on the slot_num arg.

    NOTE: The slot is not validated by this function.  The caller should validate the slot as needed.

    It is up the caller to create, if needed, the JSON lock file.
    """

    # setup
    #
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - canonical firewall checks on the username arg
    #
    if not check_username_arg(username):

        # The check_username_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a username firewall check failure.
        #
        return None

    # firewall - canonical firewall checks on the slot_num arg
    #
    if not check_slot_num_arg(slot_num):

        # The check_slot_num_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a slot_num firewall check failure.
        #
        return None

    # validate args
    #
    if not isinstance(slot_dict, dict):
        return 'slot_dict arg is not a python dictionary'

    # determine JSON slot directory path
    #
    slot_dir = return_slot_dir_path(username, slot_num)
    if not slot_dir:
        error(f'{me}: return_slot_dir_path failed for username: {username} slot_num: {slot_num}')
        return None

    # obtain path of the submit filename
    #
    if not 'filename' in slot_dict:
        error(f'{me}: submit filename missing from slot JSON file for username: {username} slot_num: {slot_num}')
        return None
    if not slot_dict['filename']:
        # no submit file has ever been uploaded to this slot
        return None
    if not isinstance(slot_dict['filename'], str):
        error(f'{me}: submit filename is not a string for username: {username} slot_num: {slot_num}')
        return None

    # return submit filename
    #
    submit_path = f'{slot_dir}/{slot_dict["filename"]}'
    debug(f'{me}: end: returning submit_path: {submit_path}')
    return submit_path
#
# pylint: enable=too-many-return-statements


def ioccc_file_lock(file_lock):
    """
    Lock a file

    A side effect of locking a file is that the file will be created with
    more 0664 it it does not exist.

    Given:
        file_lock               the filename to lock

        If the filename does not exist, it will be created.
        If another file is currently unlocked, force the older lock to be unlocked.
        Lock the new file.
        Register the lock.

    Returns:
        lock file descriptor    lock successful
        None                    lock not successful, or
                                unable to create the lock file
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_lock_fd
    # pylint: disable-next=global-statement
    global ioccc_last_lock_path
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - check arg
    #
    if not isinstance(file_lock, str):
        ioccc_last_errmsg = f'ERROR: {me}: file_lock arg not a string'
        error(f'{me}: file_lock arg not a string')
        return None

    # firewall - be sure the lock file exists
    #
    try:
        Path(file_lock).touch(mode=0o664, exist_ok=True)

    except OSError as errcode:
        ioccc_last_errmsg = (
            f'ERROR: {me}: failed touch (mode=0o664, exist_ok=True): '
            f'{file_lock} failed: <<{errcode}>>')
        error(f'{me}: touch file_lock: {file_lock} failed: <<{errcode}>>')
        return None

    # firewall - must be writable
    #
    if not os.access(file_lock, os.W_OK):
        ioccc_last_errmsg = f'ERROR: {me}: file lock not writable: {file_lock}'
        error(f'{me}: file lock not writable: {file_lock}')
        return None

    # firewall - deal with a case where we have a lock fd without a lock path
    #
    if ioccc_last_lock_fd and not ioccc_last_lock_path:
        ioccc_last_lock_path = "((no-ioccc_last_lock_path))"
        warning(f'{me}: file lock w/o lock path, forcing path to be: {ioccc_last_lock_path}')
        # fall thru

    # Force any stale lock to become unlocked
    #
    if ioccc_last_lock_fd:

        # case: previous lock is still locked
        #
        if ioccc_last_lock_fd.is_locked:

            # force unlock
            #
            ioccc_last_errmsg = f'Warning: {me}: forcing unlock of old lock for: {ioccc_last_lock_path}'
            warning(f'{me}: forcing unlock of old lock for: {ioccc_last_lock_path}')
            ioccc_last_lock_fd.release()

        # case: previous lock is unlocked
        #
        else:
            ioccc_last_errmsg = f'Warning: {me}: old lock state is unlocked: {ioccc_last_lock_path}'
            warning(f'{me}: old lock state is unlocked: {ioccc_last_lock_path}')

        # clear the lock record
        #
        ioccc_last_lock_fd = None
        ioccc_last_lock_path = None

    # prepare the lock
    #
    ioccc_last_lock_fd = FileLock(file_lock, timeout=LOCK_TIMEOUT, blocking=True, is_singleton=True)
    ioccc_last_lock_path = file_lock

    # attempt to obtain the lock
    #
    try:
        ioccc_last_lock_fd.acquire(poll_interval=LOCK_INTERVAL)

    except Timeout:

        # too too long to get the lock
        #
        ioccc_last_errmsg = f'Warning: {me}: lock timeout after {LOCK_TIMEOUT} secs for: {ioccc_last_lock_path}'
        warning(f'{me}: lock timeout file_lock: {file_lock}')
        return None

    # firewall - verify the lock
    #
    if not ioccc_last_lock_fd.is_locked:
        ioccc_last_errmsg = f'Warning: {me}: failed to keep lock for: {ioccc_last_lock_path}'
        warning(f'{me}: failed to keep lock for: {ioccc_last_lock_path}')
        ioccc_last_lock_fd = None
        ioccc_last_lock_path = None
        return None

    # record lock path
    #
    ioccc_last_lock_path = file_lock

    # return the lock success
    #
    debug(f'{me}: end: locked: {ioccc_last_lock_path}')
    return ioccc_last_lock_fd


def ioccc_file_unlock() -> None:
    """
    unlock a previously locked file

    A file locked via ioccc_file_lock(file_lock) is unlocked using the last registered lock.
    """

    # setup
    #
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # declare global use
    #
    # pylint: disable-next=global-statement
    global ioccc_last_lock_fd
    # pylint: disable-next=global-statement
    global ioccc_last_lock_path
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name

    # firewall - deal no lock path
    #
    if not ioccc_last_lock_path:
        ioccc_last_lock_path = "((no-ioccc_last_lock_path))"
        warning(f'{me}: no lock path, forcing lock path to be: {ioccc_last_lock_path}')
        # fall thru

    # case: no lock, nothing to do
    #
    if not ioccc_last_lock_fd:
        ioccc_last_errmsg = f'Notice: no lock to unlock for: {ioccc_last_lock_path}'
        info(f'{me}: no lock to unlock for: {ioccc_last_lock_path}')
        ioccc_last_lock_path = None
        return

    # release the lock
    #
    ioccc_last_lock_fd.release()
    saved_ioccc_last_lock_path = ioccc_last_lock_path
    ioccc_last_lock_fd = None
    ioccc_last_lock_path = None

    # Return the unlock success or failure
    #
    debug(f'{me}: end: unlocked: {saved_ioccc_last_lock_path}')
    return


def read_pwfile():
    """
    Return the JSON contents of the password file as a python dictionary

    Obtain a lock for password file before opening and reading the password file.
    We release the lock for the password file afterwards.

    Returns:
        None ==> unable to read the JSON in the password file
        != None ==> password file contents as a python dictionary
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # If there is no password file, or if the password file is empty, copy it from the initial password file
    #
    if not os.path.isfile(PW_FILE) or os.path.getsize(PW_FILE) <= 0:
        try:
            shutil.copy2(INIT_PW_FILE, PW_FILE, follow_symlinks=True)
        except OSError as errcode:
            ioccc_last_errmsg = f'ERROR: {me}: #0: cannot cp -p {INIT_PW_FILE} {PW_FILE} failed: <<{errcode}>>'
            error(f'{me}: cp -p {INIT_PW_FILE} {PW_FILE} failed: <<{errcode}>>')
            return None

    # prepare the lock the password file
    #
    lock_fd = FileLock(PW_LOCK, timeout=LOCK_TIMEOUT, blocking=True)

    # attempt to obtain the lock
    #
    try:

        # acquire the lock of the password file
        #
        debug(f'{me}: about to lock: {PW_LOCK}')
        lock_fd.acquire(poll_interval=LOCK_INTERVAL)

        # open, temporarily lock, load the password file and unlock
        #
        try:
            with open(PW_FILE, 'r', encoding='utf-8') as j_pw:

                # read the JSON of the password file
                #
                pw_file_json = json.load(j_pw)

                # release the lock of the password file
                #
                lock_fd.release()
                debug(f'{me}: unlocked: {PW_LOCK}')

                # firewall
                #
                if not pw_file_json:

                    # we have no JSON to return
                    #
                    ioccc_last_errmsg = (f'ERROR: {me}: failed to read password '
                                         f'file: {PW_FILE} failed: <<{errcode}>>')
                    error(f'{me}: read {PW_FILE} failed: <<{errcode}>>')
                    return None

        except OSError as errcode:
            ioccc_last_errmsg = f'ERROR: {me}: cannot read password file: {PW_FILE} failed: <<{errcode}>>'
            error(f'{me}: open for reading {PW_FILE} failed: <<{errcode}>>')

            # release the lock of the password file
            #
            lock_fd.release()
            debug(f'{me}: unlocked: {PW_LOCK}')

            # we have no JSON to return
            #
            return None

    except Timeout:

        # password file lock timeout
        #
        debug(f'{me}: failed to lock: {PW_LOCK}')
        ioccc_last_errmsg = f'Warning: {me}: lock timeout after {LOCK_TIMEOUT} secs for: {PW_LOCK}'
        warning(f'{me}: lock timeout file_lock: {PW_LOCK}')
        return None

    # return the password JSON data as a python dictionary
    #
    debug(f'{me}: end: loaded password file: {PW_FILE}')
    return pw_file_json


def replace_pwfile(pw_file_json):
    """
    Replace the contents of the password file

    Obtain a lock for password file before opening and writing JSON to the password file.
    We release the lock for the password file afterwards.

    Given:
        pw_file_json    JSON to write into the password file as a python dictionary

    Returns:
        False ==> unable to write JSON into the password file
        True ==> password file was successfully updated
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # Lock the password file
    #
    pw_lock_fd = ioccc_file_lock(PW_LOCK)
    if not pw_lock_fd:
        error(f'{me}: failed to lock file for PW_LOCK: {PW_LOCK}')
        return False

    # rewrite the password file with the pw_file_json and unlock
    #
    try:
        with open(PW_FILE, mode="w", encoding="utf-8") as j_pw:
            j_pw.write(json.dumps(pw_file_json, ensure_ascii=True, indent=4))
            j_pw.write('\n')

            # close and unlock the password file
            #
            # NOTE: We explicitly manage the close because we just did a write
            #       and we want to catch the case where a write buffer may have
            #       not been fully flushed to the file.
            #
            try:
                j_pw.close()

            except OSError as errcode:
                ioccc_last_errmsg = f'ERROR: {me}: failed to close: password file: {PW_FILE} failed: <<{errcode}>>'
                error(f'{me}: close for writing {PW_FILE} failed: <<{errcode}>>')
                ioccc_file_unlock()
                return False

    except OSError:

        # unlock the password file
        #
        ioccc_last_errmsg = f'ERROR: {me}: unable to write password file: {PW_FILE} failed: <<{errcode}>>'
        error(f'{me}: close for writing {PW_FILE} failed: <<{errcode}>>')
        ioccc_file_unlock()
        return False

    # password file updated
    #
    ioccc_file_unlock()
    debug(f'{me}: end: updated password file: {PW_FILE}')
    return True


# pylint: disable=too-many-return-statements
# pylint: disable=too-many-branches
# pylint: disable=too-many-statements
#
def validate_user_dict_nolock(user_dict):
    """
    Perform firewall checks on the user information as python dictionary for a
    given username in the password file.

    Given:
        user_dict    user information as a python dictionary

    Returns:
        True ==> no error found in in user information
        False ==> a problem was found in user JSON information

    WARNING: This function does NOT lock.  The caller should lock as needed.
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - check argument
    #
    if not isinstance(user_dict, dict):
        ioccc_last_errmsg = f'ERROR: {me}: user_dict arg is not a python dictionary'
        error(f'{me}: user_dict arg is not a python dictionary')
        return False

    # obtain the username
    #
    if not 'username' in user_dict:
        ioccc_last_errmsg = f'ERROR: {me}: username is missing from user_dict'
        error(f'{me}: username is missing from user_dict')
        return False
    if not isinstance(user_dict['username'], str):
        ioccc_last_errmsg = f'ERROR: {me}: username is not a string: <<{user_dict["username"]}>>'
        error(f'{me}: username is not a string')
        return False
    username = user_dict['username']

    # firewall - canonical firewall checks on the username string
    #
    if not check_username_arg(username):

        # The check_username_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a username firewall check failure.
        #
        return False

    # firewall check user no_comment
    #
    if not 'no_comment' in user_dict:
        ioccc_last_errmsg = f'ERROR: {me}: no_comment is missing from user_dict'
        error(f'{me}: no_comment is missing from user_dict')
        return False
    if not isinstance(user_dict['no_comment'], str):
        ioccc_last_errmsg = f'ERROR: {me}: no_comment is not a string for username: {username}'
        error(f'{me}: no_comment not a string for username: {username}')
        return False
    if user_dict['no_comment'] != NO_COMMENT_VALUE:
        ioccc_last_errmsg = f'ERROR: {me}: invalid JSON no_comment username: {username}'
        error(f'{me}: invalid JSON no_comment for username: {username} '
              f'user_dict["no_comment"]: {user_dict["no_comment"]} != '
              f'NO_COMMENT_VALUE: {NO_COMMENT_VALUE}')
        return False

    # firewall check user iocccpasswd_format_version
    #
    if not 'iocccpasswd_format_version' in user_dict:
        ioccc_last_errmsg = f'ERROR: {me}: iocccpasswd_format_version is missing from user_dict'
        error(f'{me}: iocccpasswd_format_version is missing from user_dict')
        return False
    if not isinstance(user_dict['iocccpasswd_format_version'], str):
        ioccc_last_errmsg = f'ERROR: {me}: iocccpasswd_format_version is not a string for username: {username}'
        error(f'{me}: iocccpasswd_format_version not a string for username: {username}')
        return False
    if user_dict['iocccpasswd_format_version'] != PASSWORD_VERSION_VALUE:
        ioccc_last_errmsg = f'ERROR: {me}: invalid iocccpasswd_format_version for username: {username}'
        error(f'{me}: invalid iocccpasswd_format_version for username: {username} iocccpasswd_format_version: '
              f'<<{user_dict["iocccpasswd_format_version"]}>> != PASSWORD_VERSION_VALUE: {PASSWORD_VERSION_VALUE}')
        return False

    # firewall check pwhash for user
    #
    if not 'pwhash' in user_dict:
        ioccc_last_errmsg = f'ERROR: {me}: pwhash is missing from user_dict'
        error(f'{me}: pwhash is missing from user_dict')
        return False
    if not isinstance(user_dict['pwhash'], str):
        ioccc_last_errmsg = f'ERROR: {me}: pwhash is not a string for username: {username}'
        error(f'{me}: pwhash not a string for username: {username}')
        return False

    # firewall check ignore_date for user
    #
    if not 'ignore_date' in user_dict:
        ioccc_last_errmsg = f'ERROR: {me}: ignore_date is missing from user_dict'
        error(f'{me}: ignore_date is missing from user_dict')
        return False
    if not isinstance(user_dict['ignore_date'], bool):
        ioccc_last_errmsg = f'ERROR: {me}: ignore_date is not a boolean for username: {username}'
        error(f'{me}: ignore_date not a boolean for username: {username}')
        return False

    # firewall check force_pw_change for user
    #
    if not 'force_pw_change' in user_dict:
        ioccc_last_errmsg = f'ERROR: {me}: force_pw_change is missing from user_dict'
        error(f'{me}: force_pw_change is missing from user_dict')
        return False
    if not isinstance(user_dict['force_pw_change'], bool):
        ioccc_last_errmsg = f'ERROR: {me}: force_pw_change is not a boolean for username: {username}'
        error(f'{me}: force_pw_change not a boolean for username: {username}')
        return False

    # firewall check pw_change_by for user
    #
    if not 'pw_change_by' in user_dict:
        ioccc_last_errmsg = f'ERROR: {me}: pw_change_by is missing from user_dict'
        error(f'{me}: pw_change_by is missing from user_dict')
        return False
    if user_dict['pw_change_by'] and not isinstance(user_dict['pw_change_by'], str):
        ioccc_last_errmsg = f'ERROR: {me}: pw_change_by is not null nor string for username: {username}'
        error(f'{me}: pw_change_by not null nor string for for username: {username}')
        return False

    # firewall check disable_login for user
    #
    if not 'disable_login' in user_dict:
        ioccc_last_errmsg = f'ERROR: {me}: disable_login is missing from user_dict'
        error(f'{me}: disable_login is missing from user_dict')
        return False
    if not isinstance(user_dict['disable_login'], bool):
        ioccc_last_errmsg = f'ERROR: {me}: disable_login is not a boolean for username: {username}'
        error(f'{me}: disable_login not a boolean for username: {username}')
        return False

    # user information passed the firewall checks
    #
    debug(f'{me}: end: passed all firewall checks for username: {username}')
    return True
#
# pylint: enable=too-many-return-statements
# pylint: enable=too-many-branches
# pylint: enable=too-many-statements


# pylint: disable=too-many-return-statements
#
def lookup_username(username):
    """
    Return JSON information for username from password file as a python dictionary

    Given:
        username    IOCCC submit server username

    Returns:
        None ==> no such username, or
                 username does not match POSIX_SAFE_RE, or
                 bad password file
        != None ==> user information as a python dictionary

    NOTE: This function performs various canonical firewall checks on the username arg.
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - canonical firewall checks on the username arg
    #
    if not check_username_arg(username):

        # The check_username_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a username firewall check failure.
        #
        return None

    # load JSON from the password file as a python dictionary
    #
    pw_file_json = read_pwfile()
    if not pw_file_json:
        error(f'{me}: read_pwfile failed for username: {username}')
        return None

    # search the password file for the user
    #
    user_dict = None
    for i in pw_file_json:
        if 'username' in i and i['username'] == username:
            user_dict = i
            break
    if not user_dict:
        ioccc_last_errmsg = f'ERROR: {me}: unknown username: {username}'
        debug(f'{me}: failed to find in password file for username: {username}')
        return None

    # firewall check the user information for user
    #
    if not validate_user_dict_nolock(user_dict):
        error(f'{me}: invalid user information for username: {username}')
        return None

    # return user information for user in the form of a python dictionary
    #
    debug(f'{me}: end: returning python dictionary for username: {username}')
    return user_dict
#
# pylint: enable=too-many-return-statements


# pylint: disable=too-many-statements
# pylint: disable=too-many-branches
# pylint: disable=too-many-return-statements
# pylint: disable=too-many-positional-arguments
# pylint: disable=too-many-arguments
#
def update_username(username, pwhash, ignore_date, force_pw_change, pw_change_by, disable_login):
    """
    Update a username entry in the password file, or add the entry
    if the username is not already in the password file.

    Given:
        username            IOCCC submit server username
        pwhash              hashed password as generated by hash_password()
        ignore_date         boolean indicating if the user may login when contest is not open
        force_pw_change     boolean indicating if the user will be forced to change their password on next login
        pw_change_by        date and time string in DATETIME_USEC_FORMAT by which password must be changed, or
                            None ==> no deadline for changing password
        disable_login       boolean indicating if the user is banned from login

    Returns:
        False ==> unable to update user in the password file
        True ==> user updated, or
                 added to the password file

    NOTE: This function performs various canonical firewall checks on the username arg.
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - canonical firewall checks on the username arg
    #
    if not check_username_arg(username):

        # The check_username_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a username firewall check failure.
        #
        return False

    # firewall - username arg must be a string
    #
    if not isinstance(username, str):
        ioccc_last_errmsg = f'{me}: username arg is not a string'
        info(f'{me}: username arg is not a string')
        return False

    # firewall - pwhash must be a string
    #
    if not isinstance(pwhash, str):
        ioccc_last_errmsg = f'ERROR: {me}: pwhash arg is not a string for username: {username}'
        error(f'{me}: pwhash arg is not a string')
        return False

    # firewall - ignore_date must be a boolean
    #
    if not isinstance(ignore_date, bool):
        ioccc_last_errmsg = f'ERROR: {me}: ignore_date arg is not a boolean for username: {username}'
        error(f'{me}: ignore_date arg is not a boolean')
        return False

    # firewall - force_pw_change must be a boolean
    #
    if not isinstance(force_pw_change, bool):
        ioccc_last_errmsg = f'ERROR: {me}: force_pw_change arg is not a boolean for username: {username}'
        error(f'{me}: force_pw_change arg is not a boolean')
        return False

    # firewall - pw_change_by must None or must be be string
    #
    if not isinstance(pw_change_by, str) and pw_change_by is not None:
        ioccc_last_errmsg = f'ERROR: {me}: pw_change_by arg is not a string nor None for username: {username}'
        error(f'{me}: pw_change_by arg is not a string')
        return False

    # firewall - disable_login must be a boolean
    #
    if not isinstance(disable_login, bool):
        ioccc_last_errmsg = f'ERROR: {me}: disable_login arg is not a boolean for username: {username}'
        error(f'{me}: disable_login arg is not a boolean')
        return False

    # firewall - username cannot be too short
    #
    if len(username) < MIN_USERNAME_LENGTH:
        ioccc_last_errmsg = f'{me}: username arg is too short: {len(username)} < {MIN_USERNAME_LENGTH}'
        info(f'{me}: username arg is too short: {len(username)} < {MIN_USERNAME_LENGTH}')
        return False

    # firewall - username cannot be too long
    #
    if len(username) > MAX_USERNAME_LENGTH:
        ioccc_last_errmsg = f'{me}: username arg is too long: {len(username)} > {MIN_USERNAME_LENGTH}'
        info(f'{me}: username arg is too long: {len(username)} > {MIN_USERNAME_LENGTH}')
        return False

    # firewall - username must be a POSIX safe filename string
    #
    # This also prevents username with /, and prevents it from being empty string,
    # thus one cannot create a username with system cracking "funny business".
    #
    if not re.match(POSIX_SAFE_RE, username):
        ioccc_last_errmsg = f'ERROR: {me}: username arg not POSIX safe'
        info(f'{me}: username arg not POSIX safe')
        return False

    # Lock the password file
    #
    pw_lock_fd = ioccc_file_lock(PW_LOCK)
    if not pw_lock_fd:
        error(f'{me}: failed to lock file for PW_LOCK: {PW_LOCK}')
        return False

    # If there is no password file, or if the password file is empty, copy it from the initial password file
    #
    if not os.path.isfile(PW_FILE) or os.path.getsize(PW_FILE) <= 0:
        try:
            shutil.copy2(INIT_PW_FILE, PW_FILE, follow_symlinks=True)
        except OSError as errcode:
            ioccc_last_errmsg = f'ERROR: {me}: #1: cannot cp -p {INIT_PW_FILE} {PW_FILE} failed: <<{errcode}>>'
            error(f'{me}: cp -p {INIT_PW_FILE} {PW_FILE} failed: <<{errcode}>>')
            ioccc_file_unlock()
            return False

    # load the password file and unlock
    #
    try:
        with open(PW_FILE, 'r', encoding='utf-8') as j_pw:

            # read the JSON of the password file
            #
            pw_file_json = json.load(j_pw)

            # firewall
            #
            if not pw_file_json:

                # we have no JSON to return
                #
                ioccc_last_errmsg = f'ERROR: {me}: failed to read password file: {PW_FILE} failed: <<{errcode}>>'
                error(f'{me}: read {PW_FILE} failed: <<{errcode}>>')
                ioccc_file_unlock()
                return False

    except OSError as errcode:

        # unlock the password file
        #
        ioccc_last_errmsg = f'ERROR: {me}: cannot read password file: {PW_FILE} failed: <<{errcode}>>'
        error(f'{me}: open for reading {PW_FILE} failed: <<{errcode}>>')
        ioccc_file_unlock()
        return False

    # scan through the password file, looking for the user
    #
    found_username = False
    for i in pw_file_json:
        if 'username' in i and i['username'] == username:

            # user found, update user info
            #
            i['pwhash'] = pwhash
            i['ignore_date'] = ignore_date
            i['force_pw_change'] = force_pw_change
            i['pw_change_by'] = pw_change_by
            i['disable_login'] = disable_login
            found_username = True
            break

    # the user is new, add the user to the JSON from the password file
    #
    if not found_username:

        # append the new user to the password file
        #
        pw_file_json.append({ "no_comment" : NO_COMMENT_VALUE,
                              "iocccpasswd_format_version" : PASSWORD_VERSION_VALUE,
                              "username" : username,
                              "pwhash" : pwhash,
                              "ignore_date" : ignore_date,
                              "force_pw_change" : force_pw_change,
                              "pw_change_by" : pw_change_by,
                              "disable_login" : disable_login })

    # rewrite the password file with the pw_file_json and unlock
    #
    try:
        with open(PW_FILE, mode="w", encoding="utf-8") as j_pw:
            j_pw.write(json.dumps(pw_file_json, ensure_ascii=True, indent=4))
            j_pw.write('\n')

            # close and unlock the password file
            #
            # NOTE: We explicitly manage the close because we just did a write
            #       and we want to catch the case where a write buffer may have
            #       not been fully flushed to the file.
            #
            try:
                j_pw.close()

            except OSError as errcode:
                ioccc_last_errmsg = f'ERROR: {me}: failed to close: {PW_FILE} failed: <<{errcode}>>'
                error(f'{me}: close for writing {PW_FILE} failed: <<{errcode}>>')
                ioccc_file_unlock()
                return False

    except OSError as errcode:
        ioccc_last_errmsg = f'ERROR: {me}: unable to write password file: {PW_FILE} failed: <<{errcode}>>'
        error(f'{me}: open for writing {PW_FILE} failed: <<{errcode}>>')

        # unlock the password file
        #
        ioccc_file_unlock()
        return False

    # password updated with new username information
    #
    debug(f'{me}: end: password file updated for username: {username}')
    ioccc_file_unlock()
    return True
#
# pylint: enable=too-many-statements
# pylint: enable=too-many-branches
# pylint: enable=too-many-return-statements
# pylint: enable=too-many-positional-arguments
# pylint: enable=too-many-arguments


# pylint: disable=too-many-return-statements
# pylint: disable=too-many-statements
# pylint: disable=too-many-branches
#
def delete_username(username):
    """
    Remove a username from the password file

    Given:
        username    IOCCC submit server username to remove

    Returns:
        None ==> no such username, or
                 username does not match POSIX_SAFE_RE, or
                 bad password file
        != None ==> removed user information as a python dictionary

    NOTE: This function performs various canonical firewall checks on the username arg.
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - canonical firewall checks on the username arg
    #
    if not check_username_arg(username):

        # The check_username_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a username firewall check failure.
        #
        return None

    # Lock the password file
    #
    pw_lock_fd = ioccc_file_lock(PW_LOCK)
    if not pw_lock_fd:
        error(f'{me}: failed to lock file for PW_LOCK: {PW_LOCK}')
        return None

    # If there is no password file, or if the password file is empty, copy it from the initial password file
    #
    if not os.path.isfile(PW_FILE) or os.path.getsize(PW_FILE) <= 0:
        try:
            shutil.copy2(INIT_PW_FILE, PW_FILE, follow_symlinks=True)
        except OSError as errcode:
            ioccc_last_errmsg = f'ERROR: {me}: #2: cannot cp -p {INIT_PW_FILE} {PW_FILE} failed: <<{errcode}>>'
            error(f'{me}: cp -p {INIT_PW_FILE} {PW_FILE} failed: <<{errcode}>>')
            ioccc_file_unlock()
            return None

    # load the password file and unlock
    #
    try:
        with open(PW_FILE, 'r', encoding='utf-8') as j_pw:

            # read the JSON of the password file
            #
            pw_file_json = json.load(j_pw)

            # firewall
            #
            if not pw_file_json:

                # we have no JSON to return
                #
                ioccc_last_errmsg = f'ERROR: {me}: failed to read password file: {PW_FILE} failed: <<{errcode}>>'
                error(f'{me}: read {PW_FILE} failed: <<{errcode}>>')
                ioccc_file_unlock()
                return None

    except OSError as errcode:

        # unlock the password file
        #
        ioccc_last_errmsg = f'ERROR: {me}: cannot read password file: {PW_FILE} failed: <<{errcode}>>'
        error(f'{me}: open for reading {PW_FILE} failed: <<{errcode}>>')
        ioccc_file_unlock()
        return None

    # scan through the password file, looking for the user
    #
    deleted_user = None
    new_pw_file_json = []
    for i in pw_file_json:

        # set aside the username we are deleting
        #
        if 'usernamne' in i and i['username'] == username:
            deleted_user = i

        # otherwise save other users
        #
        else:
            new_pw_file_json.append(i)

    # rewrite the password file with the pw_file_json and unlock
    #
    try:
        with open(PW_FILE, mode="w", encoding="utf-8") as j_pw:
            j_pw.write(json.dumps(new_pw_file_json, ensure_ascii=True, indent=4))
            j_pw.write('\n')

            # close and unlock the password file
            #
            # NOTE: We explicitly manage the close because we just did a write
            #       and we want to catch the case where a write buffer may have
            #       not been fully flushed to the file.
            #
            try:
                j_pw.close()

            except OSError as errcode:
                ioccc_last_errmsg = f'ERROR: {me}: failed to close: password file: {PW_FILE} failed: <<{errcode}>>'
                error(f'{me}: close for writing {PW_FILE} failed: <<{errcode}>>')
                ioccc_file_unlock()
                return None

    except OSError as errcode:

        # unlock the password file
        #
        ioccc_last_errmsg = f'ERROR: {me}: unable to write password file: {PW_FILE} failed: <<{errcode}>>'
        error(f'{me}: open for writing {PW_FILE} failed: <<{errcode}>>')
        ioccc_file_unlock()
        return None

    # return the user that was deleted, if they were found
    #
    debug(f'{me}: end: deleted username: {username}')
    ioccc_file_unlock()
    return deleted_user
#
# pylint: enable=too-many-return-statements
# pylint: enable=too-many-statements
# pylint: enable=too-many-branches


def generate_password():
    """
    Generate a random password.

    Returns:
        password string
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_pw_words
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')
    blacklist = set('`"\\')
    punct = ''.join( c for c in string.punctuation if c not in blacklist )

    # load the word dictionary if it is empty
    #
    if not ioccc_pw_words:
        try:
            with open(PW_WORDS, "r", encoding="utf-8") as f:

                try:
                    ioccc_pw_words = [word.strip() for word in f]

                except OSError as errcode:
                    ioccc_last_errmsg = (
                        f'ERROR: {me}: failed to read: word '
                        f'dictionary: {PW_WORDS} failed: <<{errcode}>>')
                    error(f'{me}: reading {PW_WORDS} failed: <<{errcode}>>')

                    # generate a random password string based on UUID, a "++" and a f9.4 number
                    #
                    info(f'{me}: generating a random password string')
                    password = f'{uuid.uuid4()}++{randrange(1000)}.{randrange(1000)}'
                    ioccc_pw_words = None   # clear any word dictionary we might have read
                    return password

        except OSError as errcode:
            ioccc_last_errmsg = f'ERROR: {me}: failed to open: word dictionary: {PW_WORDS} failed: <<{errcode}>>'
            error(f'{me}: open for reading {PW_WORDS} failed: <<{errcode}>>')

            # generate a random password string based on UUID, a "**" and a f9.4 number
            #
            info(f'{me}: random password string will be generated')
            password = f'{uuid.uuid4()}**{randrange(1000)}.{randrange(1000)}'
            ioccc_pw_words = None   # clear any word dictionary we might have opened
            return password

    # generate a 2+word password with random separators and an f9.4 number
    #
    # FYI: The source for etc/pw.words is the polite English language words list from:
    #
    #   https://github.com/lcn2/polite.english.words
    #
    # when it installed as:
    #
    #   /usr/local/share/polite.words/polite.english.words.txt
    #
    # As of 2024 Dec 30 commit 979589999962b1029d25f6b9601702a6eb9f868d
    # the polite English language words file had the following word count
    # and word length in characters as follows:
    #
    #            52 1
    #           757 2
    #          2781 3
    #          8372 4
    #         18338 5
    #         34252 6
    #         47491 7
    #         57802 8
    #         59528 9
    #         51313 10
    #         41992 11
    #         32187 12
    #         22849 13
    #         15284 14
    #          9514 15
    #          5543 16
    #          3151 17
    #          1534 18
    #           790 19
    #           368 20
    #           170 21
    #            79 22
    #            32 23
    #            13 24
    #             8 25
    #             3 27
    #             2 28
    #             2 29
    #             1 31
    #
    # Using make rebuild_pw_words we build etc/pw.words from the polite English language words list
    # to form the etc/pw.words file this function reads and uses.
    #
    # The make rebuild_pw_words rule is used to select all English language words that are
    # at least MIN_POLITE_WORD_LENGTH (def: 4) and at most MAX_POLITE_WORD_LENGTH (def: 10) long,
    # where those two values come from the Makefile  As of 2024 Dec 30, this is what is used to
    # generate the etc/pw.words file.
    #
    # The minimum password length we generate is:
    #
    #   4 + 1 + 4 + 1 + 9 = 19
    #
    # The maximum password length we generate is:
    #
    #   10 + 1 + 10 + 1 + 9 = 31
    #
    # The average word in etc/pw.words. given the above is 7.847 characters.
    # This gives us an average password length of:
    #
    #  7.847 + 1 + 7.847 + 9 = 25.694
    #
    # The etc/pw.words file has about 277096 words in it (log2 ~ 18.080).
    #
    # We use punctuation symbols from list of 30 characters (log2 ~ 4.907).
    #
    # We append a f9.4 (4 decimal digits + . + 4 decimal digits) number (log2 ~ 19.932).
    #
    # The number of different password we can generate, given the above, is:
    #
    #   277096 * 30 * 277096 * 30 * 1000^2 = 69103973894400000000
    #
    # We form a password using 2 polite English language words, 2 punctuation symbols, and
    # a f9.4 number, so we will have the following password entropy:
    #
    #   log2(277096)*2 + log2(30)*2 + log2(1000)*2 = 65.905 bits of entropy
    #
    # That gives us enough surprise for an initial password that users of the submit server will
    # be required to change when they first login.
    #
    password = (
        f'{secrets.choice(ioccc_pw_words)}{random.choice(punct)}{secrets.choice(ioccc_pw_words)}'
        f'{random.choice(punct)}{randrange(1000)}.{randrange(1000)}')
    debug(f'{me}: end: returning generated password: {password}')
    return password


def hash_password(password):
    """
    Convert a password into a hashed password.

    Given:
        password    password as a string

    Returns:
        != None ==> hashed password string
        None ==> invalid arg
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - password must be a string
    #
    if not isinstance(password, str):
        ioccc_last_errmsg = f'ERROR: {me}: password arg is not a string'
        error(f'{me}: password arg is not a string')
        return None

    hashed_password = generate_password_hash(password)
    debug(f'{me}: end: returning hashed password: {hashed_password}')
    return hashed_password


def verify_hashed_password(password, pwhash):
    """
    Verify that password matches the hashed patches

    Given:
        password    plaintext password
        pwhash      hashed password

    Returns:
        True ==> password matches the hashed password
        False ==> password does NOT match the hashed password, or
                  a non-string args was found
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - password must be a string
    #
    if not isinstance(password, str):
        ioccc_last_errmsg = f'ERROR: {me}: password arg is not a string'
        error(f'{me}: password arg is not a string')
        return False

    # firewall - pwhash must be a string
    #
    if not isinstance(pwhash, str):
        ioccc_last_errmsg = f'ERROR: {me}: pwhash arg is not a string'
        error(f'{me}: pwhash arg is not a string')
        return False

    # return if the pwhash matches the password
    #
    match = check_password_hash(pwhash, password)
    debug(f'{me}: end: check_password_hash: {match}')
    return match


# pylint: disable=too-many-return-statements
#
def verify_user_password(username, password):
    """
    Verify a password for a given user

    Given:
        username    IOCCC submit server username
        password    plaintext password

    Returns:
        True ==> password matches the hashed password
        False ==> password does NOT match the hashed password, or
                  username is not in the password database, or
                  user is not allowed to login, or
                  a non-string args was found

    NOTE: This function performs various canonical firewall checks on the username arg.
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - canonical firewall checks on the username arg
    #
    if not check_username_arg(username):

        # The check_username_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a username firewall check failure.
        #
        return False

    # firewall - password must be a string
    #
    if not isinstance(password, str):
        ioccc_last_errmsg = f'ERROR: {me}: password arg is not a string'
        error(f'{me}: password arg is not a string')
        return False

    # obtain the python dictionary for the username
    #
    # fail if user login is disabled or missing from the password file
    #
    user_dict = lookup_username(username)
    if not user_dict:

        # user is not in the password file, so we cannot state they have been disabled
        #
        debug(f'{me}: lookup_username failed for username: {username}')
        return False

    # fail if the user is not allowed to login
    #
    if not user_allowed_to_login(user_dict):

        # user is not allowed to login
        #
        info(f'{me}: login not allowed for username: {username}')
        return False

    # paranoia - just have a pwhash
    #
    if not 'pwhash' in user_dict:
        info(f'{me}: missing pwhash for username: {username}')
        return False

    # return the result of the hashed password check for this user
    #
    verify = verify_hashed_password(password, user_dict['pwhash'])
    debug(f'{me}: end: verify_hashed_password: {verify}')
    return verify
#
# pylint: enable=too-many-return-statements


# pylint: disable=too-many-return-statements
#
def is_pw_pwned(password):
    """
    Determine if a password has bee pwned by doing a lookup
    in the Pwned password tree.

    Given:
        password    plaintext password

    Returns:
        True ==> password found in the Pwned password tree with a pwned count > 0, or
                  failed to SHA-1 hash the password in UPPER CASE hex characters,
                  failed to open or read the required Pwned password tree file,
                  non-string arg was found
        False ==> password not found in the Pwned password tree, or
                  pwned count <= 0

    Regarding the Pwned password tree:

    The pwned password tree has 4 levels.  Files are of the form:

        i/j/k/ikjxy

    where i, j, k, x, y are UPPER CASE hex digits:

        0 1 2 3 4 5 6 7 8 9 A B C D E F

    Each file is of the form:

    35-UPPER-CASE-HEX-digits, followed by a colon (":"), followed by an integer > 0

    For eample, all pwned passwords with a SHA-1 that begin with `12345` will be found in:

        1/2/3/12345

    NOTE: The first 1 SHA-1 HEX characters are duplicated in the 3 directory levels.

    Example: a line from 1/2/3/12345

    The 1/2/3/12345 file contains the following line:

        00772720168B19640759677862AD5350374:4

    The SHA-1 hash of the pwned password is the 1st 5 HEX digits from the file,
    plus the 35 hex digits of the line before the colon (":").  Thus the
    SHA-1 hash of the pwned password is:

        1234500772720168B19640759677862AD5350374

    The "4" after the colon (":") means that the given password has been pwned at
    least 4 times and should NOT be used.

    Consider the password:

        password

    The SHA-1 hash of "password" is:

        5BAA61E4C9B93F3F0682250B6CF8331B7EE68FD8

    Using the first 5 hex digits, open the file:

        5/B/A/5BAA6

    Using Unix tools, we can look for the remaining 35 hex digits followed by a ":"

        grep -F 1E4C9B93F3F0682250B6CF8331B7EE68FD8: 5/B/A/5BAA6

    This will produce the line:

        1E4C9B93F3F0682250B6CF8331B7EE68FD8:10437277

    This indicates that the password "`password`", has been pwned at least 10437277 times!
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - password must be a string
    #
    if not isinstance(password, str):
        ioccc_last_errmsg = f'ERROR: {me}: password arg is not a string'
        error(f'{me}: password arg is not a string')
        return True

    # compute the SHA-1 of the password in UPPER CASE hex
    #
    m = hashlib.sha1()
    if not m:
        ioccc_last_errmsg = f'ERROR: {me}: unable to form a context for SHA-1 hashing'
        error(f'{me}: unable to form a context for SHA-1 hashing')
        return True
    m.update(bytes(password, 'utf-8'))
    sha1_hex = m.hexdigest().upper()
    if not sha1_hex or len(sha1_hex) != SHA1_HEXLEN:
        ioccc_last_errmsg = f'ERROR: {me}: SHA-1 hash return was invalid'
        error(f'{me}: invalid SHA-1 hash return')
        return True

    # determine the Pwned password tree file we need to read
    #
    pwned_file = f'{PWNED_PW_TREE}/{sha1_hex[0]}/{sha1_hex[1]}/{sha1_hex[2]}/{sha1_hex[0:5]}'
    #
    try:
        with open(pwned_file, 'r', encoding='utf8') as input_file:

            # read the lines in the Pwned password tree file
            #
            lines = input_file.readlines()

            # scan the Pwned password tree file for the hash
            #
            scan_for = f'{sha1_hex[5:]}:'
            for line in lines:

                # look for the read of the SHA-1 hash
                #
                if line.startswith(scan_for):

                    # we found a match - password is Pwned
                    #
                    # NOTE: We don't care just how Pwned the password is, thus
                    #       the integer after the ":" doesn't matter in the case.
                    #
                    debug(f'{me}: Pwned password: {password}')
                    return True

    except OSError as errcode:
        ioccc_last_errmsg = f'ERROR: {me}: failed using: Pwned password tree file: {pwned_file} failed: <<{errcode}>>'
        error(f'{me}: failed open for reading: {pwned_file}')
        return True

    # We presume that the password is not Pwned
    #
    debug(f'{me}: end: password appears to not have (yet) been Pwned')
    return False
#
# pylint: enable=too-many-return-statements


def is_proper_password(password):
    """
    Determine if a password is proper.  That is, if the password
    follows the rules for a good password that as not been pwned.

    For password rule guidance, see:

        https://pages.nist.gov/800-63-4/sp800-63b.html
        https://cybersecuritynews.com/nist-rules-password-security/

    Given:
        password    plaintext password

    Returns:
        True ==> password is allowed under the rules
        False ==> password is is not allowed, or
                  non-string arg was found
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - password must be a string
    #
    if not isinstance(password, str):
        ioccc_last_errmsg = f'ERROR: {me}: password arg is not a string'
        error(f'{me}: password arg is not a string')
        return False

    # password must be at at least MIN_PASSWORD_LENGTH long
    #
    if len(password) < MIN_PASSWORD_LENGTH:
        ioccc_last_errmsg = f'ERROR: password must be at least {MIN_PASSWORD_LENGTH} characters long'
        debug(f'{me}: password is too short')
        return False

    # password must be a sane length
    #
    if len(password) > MAX_PASSWORD_LENGTH:
        ioccc_last_errmsg = f'ERROR: password must not be longer than {MAX_PASSWORD_LENGTH} characters'
        debug(f'{me}: password is too long')
        return False

    # password must not have been Pwned
    #
    if is_pw_pwned(password):
        ioccc_last_errmsg = "ERROR: new password has been Pwned (compromised), please select a different new password"
        debug(f'{me}: is_pw_pwned returned true for a password')
        return False

    # until we have password rules, allow any string
    #
    debug(f'{me}: end: password is allowed')
    return True


# pylint: disable=too-many-return-statements
# pylint: disable=too-many-branches
#
def update_password(username, old_password, new_password):
    """
    Update the password for a given user.

    NOTE: If the user is allowed to login, and the old_password is the
          current password, and the new_password is an allowed password,
          we update the user's password AND clear any force_pw_change state.

    Given:
        username        IOCCC submit server username
        old_password    current plaintext password
        new_password    new plaintext password

    Returns:
        True ==> password updated
        False ==> old_password does NOT match the hashed password, or
                  non-string args was found, or
                  username is not in the password database, or
                  user is not allowed to login, or
                  new_password is not a valid password

    NOTE: This function performs various canonical firewall checks on the username arg.
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - canonical firewall checks on the username arg
    #
    if not check_username_arg(username):

        # The check_username_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a username firewall check failure.
        #
        return False

    # firewall - old_password must be a string
    #
    if not isinstance(old_password, str):
        ioccc_last_errmsg = f'ERROR: {me}: old_password arg is not a string'
        error(f'{me}: old_password arg is not a string')
        return False

    # firewall - new_password must be a string
    #
    if not isinstance(new_password, str):
        ioccc_last_errmsg = f'ERROR: {me}: new_password arg is not a string'
        error(f'{me}: new_password arg is not a string')
        return False

    # new_password must be a proper password
    #
    if not is_proper_password(new_password):
        debug(f'{me}: is_proper_password returned false for new_password')
        return False

    # obtain the python dictionary for the username
    #
    # fail if user login is disabled or missing from the password file
    #
    user_dict = lookup_username(username)
    if not user_dict:

        # user is not in the password file, so we cannot state they have been disabled
        #
        debug(f'{me}: lookup_username failed for username: {username}')
        return False

    # fail if the user is not allowed to login
    #
    if not user_allowed_to_login(user_dict):

        # user is not allowed to login
        #
        info(f'{me}: login not allowed for username: {username}')
        return False

    # return the result of the hashed password check for this user
    #
    if not 'pwhash' in user_dict:
        ioccc_last_errmsg = f'ERROR: {me}: pwhash is missing for username: {username}'
        error(f'{me}: pwhash is missing for username: {username}')
        return False
    if not verify_hashed_password(old_password, user_dict['pwhash']):

        # old_password is not correct
        #
        ioccc_last_errmsg = "ERROR: invalid old password"
        info(f'{me}: old_password is not correct for username: {username}')
        return False

    # paranoia - must have ignore_data for this user
    #
    if not 'ignore_date' in user_dict:
        ioccc_last_errmsg = f'ERROR: {me}: ignore_date is missing for username: {username}'
        error(f'{me}: ignore_date is missing for username: {username}')
        return False

    # paranoia - must have disable_login for this user
    #
    if not 'disable_login' in user_dict:
        ioccc_last_errmsg = f'ERROR: {me}: disable_login is missing for username: {username}'
        error(f'{me}: disable_login is missing for username: {username}')
        return False

    # update user entry in the password database
    #
    # We force the force_pw_change state to be False as this action IS changing the password.
    #
    if not update_username(username,
                           hash_password(new_password),
                           user_dict['ignore_date'],
                           False,
                           None,
                           user_dict['disable_login']):
        error(f'{me}: password database update failed for username: {username}')
        return False

    # password successfully updated
    #
    debug(f'{me}: end: updated password for username: {username}')
    return True
#
# pylint: enable=too-many-return-statements
# pylint: enable=too-many-branches


# pylint: disable=too-many-return-statements
# pylint: disable=too-many-branches
#
def user_allowed_to_login(user_dict):
    """
    Determine if the user has been disabled based on the username

    Given:
        user_dict    user information for username as a python dictionary

    Returns:
        True ==> user is allowed to login
        False ==> login is not allowed for the user, or
                  user_dict failed firewall checks, or
                  user is not allowed to login, or
                  user did not change their password in time
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall check the user information
    #
    if not validate_user_dict_nolock(user_dict):
        error(f'{me}: validate_user_dict_nolock failed')
        return False
    username = user_dict['username']

    # paranoia - must have disable_login for this user_dict
    #
    if not 'disable_login' in user_dict:
        ioccc_last_errmsg = f'ERROR: {me}: disable_login is missing from user_dict'
        error(f'{me}: disable_login is missing from user_dict')
        return False

    # deny login if disable_login is true
    #
    if user_dict['disable_login']:

        # login disabled
        #
        ioccc_last_errmsg = "ERROR: user login has been disabled"
        info(f'{me}: login not allowed for username: {username}')
        return False

    # paranoia - must have disable_login for this user_dict
    #
    if not 'force_pw_change' in user_dict:
        ioccc_last_errmsg = f'ERROR: {me}: force_pw_change is missing from user_dict'
        error(f'{me}: force_pw_change is missing from user_dict')
        return False

    # paranoia - must have disable_login for this user_dict
    #
    if not 'pw_change_by' in user_dict:
        ioccc_last_errmsg = f'ERROR: {me}: pw_change_by is missing from user_dict'
        error(f'{me}: pw_change_by is missing from user_dict')
        return False

    # deny login is the force_pw_change and we are beyond the pw_change_by time limit
    #
    if user_dict['force_pw_change'] and user_dict['pw_change_by']:

        # Convert pw_change_by into a datetime string
        #
        try:
            pw_change_by = datetime.strptime(user_dict['pw_change_by'], DATETIME_USEC_FORMAT)
        except ValueError as errcode:
            ioccc_last_errmsg = (
                f'ERROR: {me}: not in datetime format: '
                f'<<{user_dict["pw_change_by"]}>> failed: <<{errcode}>>')
            error(f'{me}: datetime.strptime of pw_change_by: <<{user_dict["pw_change_by"]}>>'
                  f'failed: <<{errcode}>>')
            return False

        # determine the datetime of now
        #
        now = datetime.now(timezone.utc)

        # failed to change the password in time
        #
        if now.timestamp() > pw_change_by.timestamp():
            ioccc_last_errmsg = "ERROR: user failed to change the password in time"
            info(f'{me}: password not changed in time for username: {username}')
            return False

    # user login attempt is allowed
    #
    debug(f'{me}: end: login allowed for username: {username}')
    return True
#
# pylint: enable=too-many-return-statements
# pylint: enable=too-many-branches


def must_change_password(user_dict):
    """
    Determine if the user is required to change their password.

    Given:
        user_dict    user information for username as a python dictionary

    Returns:
        True ==> user must change their password
        False ==> user is not requited to change their password, or
                  invalid user_dict, or
                  force_pw_change is not a boolean
    """

    # setup
    #
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall check the user information
    #
    if not validate_user_dict_nolock(user_dict):
        error(f'{me}: validate_user_dict_nolock failed')
        return False

    # paranoia - must have force_pw_change in user_dict
    #
    if not 'force_pw_change' in user_dict:
        error(f'{me}: force_pw_change is missing from user_dict')
        return False

    # paranoia - force_pw_change must be a boolean
    #
    if not isinstance(user_dict['force_pw_change'], bool):
        error(f'{me}: force_pw_change is not a boolean')
        return False

    force_pw_change = user_dict['force_pw_change']
    debug(f'{me}: end: force_pw_change: {force_pw_change}')
    return force_pw_change


def username_login_allowed(username):
    """
    Determine if the user has been disabled based on the username

    Given:
        username    IOCCC submit server username

    Returns:
        True        user is allowed to login
        False       username is not in the password file, or
                    username has been disabled in the password file, or
                    user did not change their password in time, or
                    username does not match POSIX_SAFE_RE

    NOTE: This function performs various canonical firewall checks on the username arg.
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - canonical firewall checks on the username arg
    #
    if not check_username_arg(username):

        # The check_username_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a username firewall check failure.
        #
        return False

    # firewall - username arg must be a string
    #
    if not isinstance(username, str):
        ioccc_last_errmsg = f'{me}: username arg is not a string'
        info(f'{me}: username arg is not a string')
        return False

    # obtain the python dictionary for the username
    #
    # fail if user login is disabled or missing from the password file
    #
    user_dict = lookup_username(username)
    if not user_dict:

        # user is not in the password file, so we cannot state they have been disabled
        #
        debug(f'{me}: lookup_username failed for username: {username}')
        return False

    # determine, based on the user information, if the user is allowed to login
    #
    allowed = user_allowed_to_login(user_dict)
    debug(f'{me}: end: user_allowed_to_login: {allowed}')
    return allowed


# pylint: disable=too-many-return-statements
#
def lock_slot(username, slot_num):
    """
    lock a slot for a user

    A side effect of locking the slot is that the user directory will be created.
    A side effect of locking the slot is if another file is locked, that file will be unlocked.
    If it does not exist, and the slot directory for the user will be created.
    If it does not exist, and the lock file will be created .. unless we return None.

    Given:
        username    IOCCC submit server username
        slot_num    slot number for a given username

    Returns:
        lock file descriptor    lock successful
        None                    lock not successful, or
                                invalid username, or
                                invalid slot_num

    NOTE: This function performs various canonical firewall checks on the username arg.

    NOTE: This function performs various canonical firewall checks on the slot_num arg.
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')
    umask(0o022)

    # firewall - canonical firewall checks on the username arg
    #
    if not check_username_arg(username):

        # The check_username_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a username firewall check failure.
        #
        return None

    # firewall - canonical firewall checks on the slot_num arg
    #
    if not check_slot_num_arg(slot_num):

        # The check_slot_num_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a slot_num firewall check failure.
        #
        return None

    # determine user directory path
    #
    user_dir = return_user_dir_path(username)
    if not user_dir:
        error(f'{me}: return_user_dir_path failed for username: {username}')
        return None

    # determine slot directory path
    #
    slot_dir = return_slot_dir_path(username, slot_num)
    if not slot_dir:
        error(f'{me}: return_slot_dir_path failed for username: {username} slot_num: {slot_num}')
        return None

    # be sure the user directory exists
    #
    try:
        makedirs(user_dir, mode=0o2770, exist_ok=True)
    except OSError as errcode:
        ioccc_last_errmsg = f'ERROR: {me}: failed to create for username: {username} failed: <<{errcode}>>'
        error(f'{me}: mkdir for username: {username} failed: <<{errcode}>>')
        return None

    # be sure the slot directory exits
    #
    try:
        makedirs(slot_dir, mode=0o2770, exist_ok=True)

    except OSError as errcode:
        ioccc_last_errmsg = f'ERROR: {me}: failed to create slot: {slot_num} username: {username} failed: <<{errcode}>>'
        error(f'{me}: slot directory mkdir for username: {username} slot_num: {slot_num} '
              f'failed: <<{errcode}>>')
        return None

    # determine the lock filename
    #
    slot_file_lock = f'{slot_dir}/lock'

    # lock the slot
    #
    slot_lock_fd = ioccc_file_lock(slot_file_lock)

    # case: filed to lock
    #
    if not slot_lock_fd:
        ioccc_last_errmsg = f'ERROR: {me}: failed to lock: {slot_file_lock}'
        error(f'{me}: failed to lock file for slot_file_lock: {slot_file_lock}')
        return None

    # return the slot lock success or None
    #
    debug(f'{me}: end: slot locked for username: {username} slot_num: {slot_num}')
    return slot_lock_fd
#
# pylint: enable=too-many-return-statements


def unlock_slot() -> None:
    """
    unlock a previously locked slot

    A slot locked via lock_slot(username, slot_num) is unlocked
    using the last_slot_lock that noted the slot lock descriptor.

    Returns:
        True    slot unlock successful
        False    failed to unlock slot
    """

    # setup
    #
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # clear any previous lock
    #
    ioccc_file_unlock()
    debug(f'{me}: end')


# pylint: disable=too-many-return-statements
# pylint: disable=too-many-branches
# pylint: disable=too-many-statements
#
def is_slot_setup(username, slot_num):
    """
    Determine of a user's slot has been setup or needs to be initialized.

    Given:
        username    IOCCC submit server username
        slot_num    slot number for a given username

    Returns:
        True        user's slot has been setup
        False       user's slot has not been setup, or
                    user's slot needs to be rebuilt

    WARNING: This function does NOT lock.  The caller should lock as needed.
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - canonical firewall checks on the username arg
    #
    if not check_username_arg(username):

        # The check_username_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a username firewall check failure.
        #
        return False

    # firewall - canonical firewall checks on the slot_num arg
    #
    if not check_slot_num_arg(slot_num):

        # The check_slot_num_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a slot_num firewall check failure.
        #
        return False

    #########################
    # user directory checks #
    #########################

    # determine user directory path
    #
    user_dir = return_user_dir_path(username)
    if not user_dir:
        # do not log errors, let the caller (re)initialize
        ioccc_last_errmsg = f'ERROR: {me}: return_user_dir_path failed'
        return False

    # user directory must exist
    #
    if not Path(user_dir).exists():
        # do not log errors, let the caller (re)initialize
        ioccc_last_errmsg = f'Notice: {me}: user directory does not exist: {user_dir}'
        return False

    # user directory must be a directory
    #
    if not Path(user_dir).is_dir():
        # do not log errors, let the caller (re)initialize
        ioccc_last_errmsg = f'Notice: {me}: user directory is not a directory: {user_dir}'
        return False

    # user directory must be readable
    #
    if not os.access(user_dir, os.R_OK):
        # do not log errors, let the caller (re)initialize
        ioccc_last_errmsg = f'Notice: {me}: not a readable user directory: {user_dir}'
        return False

    # user directory must be writable
    #
    if not os.access(user_dir, os.W_OK):
        # do not log errors, let the caller (re)initialize
        ioccc_last_errmsg = f'Notice: {me}: not a writable user directory: {user_dir}'
        return False

    #########################
    # slot directory checks #
    #########################

    # determine slot directory path
    #
    slot_dir = return_slot_dir_path(username, slot_num)
    if not slot_dir:
        # do not log errors, let the caller (re)initialize
        ioccc_last_errmsg = f'ERROR: {me}: return_slot_dir_path failed'
        return False

    # slot directory must exist
    #
    if not Path(slot_dir).exists():
        # do not log errors, let the caller (re)initialize
        ioccc_last_errmsg = f'Notice: {me}: slot directory does not exist: {slot_dir}'
        return False

    # slot directory must be a directory
    #
    if not Path(slot_dir).is_dir():
        # do not log errors, let the caller (re)initialize
        ioccc_last_errmsg = f'Notice: {me}: slot directory is not a directory: {slot_dir}'
        return False

    # slot directory must be readable
    #
    if not os.access(slot_dir, os.R_OK):
        # do not log errors, let the caller (re)initialize
        ioccc_last_errmsg = f'Notice: {me}: not a readable slot directory: {slot_dir}'
        return False

    # slot directory must be writable
    #
    if not os.access(slot_dir, os.W_OK):
        # do not log errors, let the caller (re)initialize
        ioccc_last_errmsg = f'Notice: {me}: not a writable slot directory: {slot_dir}'
        return False

    #########################
    # slot.json file checks #
    #########################

    # determine the slot JSON file path
    #
    slot_json_file = return_slot_json_filename(username, slot_num)
    if not slot_json_file:
        # do not log errors, let the caller (re)initialize
        ioccc_last_errmsg = f'ERROR: {me}: return_slot_json_filename failed'
        return False

    # slot JSON file must exist
    #
    if not Path(slot_json_file).exists():
        # do not log errors, let the caller (re)initialize
        ioccc_last_errmsg = f'Notice: {me}: slot JSON file does not exist: {slot_json_file}'
        return False

    # slot JSON file must exist
    #
    if not Path(slot_json_file).is_file():
        # do not log errors, let the caller (re)initialize
        ioccc_last_errmsg = f'Notice: {me}: slot JSON file is not a file: {slot_json_file}'
        return False

    # slot JSON file must be readable
    #
    if not os.access(slot_json_file, os.R_OK):
        # do not log errors, let the caller (re)initialize
        ioccc_last_errmsg = f'Notice: {me}: not a readable slot JSON file: {slot_json_file}'
        return False

    # slot JSON file must be writable
    #
    if not os.access(slot_json_file, os.W_OK):
        # do not log errors, let the caller (re)initialize
        ioccc_last_errmsg = f'Notice: {me}: not a writable slot JSON file: {slot_json_file}'
        return False

    # slot JSON file must NOT be empty
    #
    if os.path.getsize(slot_json_file) <= 0:
        # do not log errors, let the caller (re)initialize
        ioccc_last_errmsg = f'Notice: {me}: empty slot JSON file: {slot_json_file}'
        return False

    #########################
    # slot lock file checks #
    #########################

    # determine the slot lock file path
    #
    slot_lock_file = return_slot_lockfile(username, slot_num)
    if not slot_lock_file:
        # do not log errors, let the caller (re)initialize
        ioccc_last_errmsg = f'ERROR: {me}: return_slot_lockfile failed'
        return False

    # slot lock file must exist
    #
    if not Path(slot_lock_file).exists():
        # do not log errors, let the caller (re)initialize
        ioccc_last_errmsg = f'Notice: {me}: slot lock file does not exist: {slot_lock_file}'
        return False

    # slot lock file must exist
    #
    if not Path(slot_lock_file).is_file():
        # do not log errors, let the caller (re)initialize
        ioccc_last_errmsg = f'Notice: {me}: slot lock file is not a file: {slot_lock_file}'
        return False

    # slot lock file must be readable
    #
    if not os.access(slot_lock_file, os.R_OK):
        # do not log errors, let the caller (re)initialize
        ioccc_last_errmsg = f'Notice: {me}: not a readable slot lock file: {slot_lock_file}'
        return False

    # slot lock file must be writable
    #
    if not os.access(slot_lock_file, os.W_OK):
        # do not log errors, let the caller (re)initialize
        ioccc_last_errmsg = f'Notice: {me}: not a writable slot lock file: {slot_lock_file}'
        return False

    ##########
    # all OK #
    ##########

    # all is OK if we reach here
    #
    debug(f'{me}: end: is_slot_setup is OK')
    return True
#
# pylint: enable=too-many-return-statements
# pylint: enable=too-many-branches
# pylint: enable=too-many-statements


def write_slot_json_nolock(slot_json_file, slot_json):
    """
    Write out an index of slots for the user.

    Given:
        slot_json_file     JSON filename for a given slot
        slot_json           content for a given slot as a python dictionary

    Returns:
        True    slot JSON file updated
        False   failed to update slot JSON file

    WARNING: This function does NOT lock.  The caller should lock as needed.
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # write JSON file for slot
    #
    try:
        with open(slot_json_file, mode="w", encoding="utf-8") as slot_file_fp:
            slot_file_fp.write(json.dumps(slot_json, ensure_ascii=True, indent=4))
            slot_file_fp.write('\n')

            # close slot file
            #
            # NOTE: We explicitly manage the close because we just did a write
            #       and we want to catch the case where a write buffer may have
            #       not been fully flushed to the file.
            #
            try:
                slot_file_fp.close()

            except OSError as errcode:
                ioccc_last_errmsg = f'ERROR: {me}: failed to close: {slot_json_file} failed: <<{errcode}>>'
                error(f'{me}: close writing for slot_json_file: {slot_json_file} '
                      f'failed: <<{errcode}>>')
                return False

    except OSError as errcode:
        ioccc_last_errmsg = f'ERROR: failed to write out slot file: {slot_json_file} failed: <<{errcode}>>'
        error(f'{me}: open for slot_json_file: {slot_json_file} failed: <<{errcode}>>')
        return False

    debug(f'{me}: end: updated slot_json_file: {slot_json_file}')
    return True


# pylint: disable=too-many-return-statements
# pylint: disable=too-many-branches
# pylint: disable=too-many-statements
#
def initialize_slot_nolock(username, slot_num):
    """
    Initialize a slot

    Given:
        username    IOCCC submit server username
        slot_num    slot number for a given username

    Returns:
        True        user's slot has been initialized
        False       user's slot has not been initialized

    WARNING: This function does NOT lock.  The caller should lock as needed.
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - canonical firewall checks on the username arg
    #
    if not check_username_arg(username):

        # The check_username_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a username firewall check failure.
        #
        return False

    # firewall - canonical firewall checks on the slot_num arg
    #
    if not check_slot_num_arg(slot_num):

        # The check_slot_num_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a slot_num firewall check failure.
        #
        return False

    ########################
    # user directory setup #
    ########################

    # determine user directory path
    #
    user_dir = return_user_dir_path(username)
    if not user_dir:
        ioccc_last_errmsg = f'ERROR: {me}: return_user_dir_path failed'
        error(f'{me}: return_user_dir_path failed')
        return False

    # create user directory if needed
    #
    if not Path(user_dir).is_dir():

        # attempt to create the user directory
        #
        try:
            makedirs(user_dir, mode=0o2770, exist_ok=True)
        except OSError as errcode:
            ioccc_last_errmsg = f'ERROR: {me}: failed to create for username: {username} failed: <<{errcode}>>'
            error(f'{me}: mkdir for username: {username} failed: <<{errcode}>>')
            return False

    # ensure that the user directory is read/write
    #
    if not os.access(user_dir, os.R_OK) or not os.access(user_dir, os.W_OK):
        try:
            os.chmod(user_dir, mode=0o2770)
        except OSError as errcode:
            ioccc_last_errmsg = f'ERROR: {me}: failed to chmod 2770 {username} failed: <<{errcode}>>'
            error(f'{me}: failed to chmod 2770 {username} failed: <<{errcode}>>')
            return False

    # firewall - user directory must be a read/write directory
    #
    if not Path(user_dir).exists() or not Path(user_dir).is_dir() or \
       not os.access(user_dir, os.R_OK) or not os.access(user_dir, os.W_OK):
        ioccc_last_errmsg = f'ERROR: {me}: user directory was not setup correctly'
        error(f'{me}: user directory was not setup correctly')
        return False

    ########################
    # slot directory setup #
    ########################

    # determine slot directory path
    #
    slot_dir = return_slot_dir_path(username, slot_num)
    if not slot_dir:
        ioccc_last_errmsg = f'ERROR: {me}: return_slot_dir_path failed'
        error(f'{me}: return_slot_dir_path failed')
        return False

    # create slot directory if needed
    #
    if not Path(slot_dir).is_dir():

        # attempt to create the slot directory
        #
        try:
            makedirs(slot_dir, mode=0o2770, exist_ok=True)
        except OSError as errcode:
            ioccc_last_errmsg = f'ERROR: {me}: failed to create for username: {username} failed: <<{errcode}>>'
            error(f'{me}: mkdir for username: {username} failed: <<{errcode}>>')
            return False

    # ensure that the slot directory is read/write
    #
    if not os.access(slot_dir, os.R_OK) or not os.access(slot_dir, os.W_OK):
        try:
            os.chmod(slot_dir, mode=0o2770)
        except OSError as errcode:
            ioccc_last_errmsg = f'ERROR: {me}: failed to chmod 2770 {username} failed: <<{errcode}>>'
            error(f'{me}: failed to chmod 2770 {username} failed: <<{errcode}>>')
            return False

    # firewall - slot directory must be a read/write directory
    #
    if not Path(slot_dir).exists() or not Path(slot_dir).is_dir() or \
       not os.access(slot_dir, os.R_OK) or not os.access(slot_dir, os.W_OK):
        ioccc_last_errmsg = f'ERROR: {me}: slot directory was not setup correctly'
        error(f'{me}: slot directory was not setup correctly')
        return False

    ########################
    # slot.json file setup #
    ########################

    # determine the slot JSON file path
    #
    slot_json_file = return_slot_json_filename(username, slot_num)
    if not slot_json_file:
        ioccc_last_errmsg = f'ERROR: {me}: return_slot_json_filename failed'
        error(f'{me}: return_slot_json_filename failed')
        return False

    # setup the JSON slot using the template
    #
    t = Template(EMPTY_JSON_SLOT_TEMPLATE)

    # initialize the slot JSON from the template
    #
    slot_json = json.loads(t.substitute( { 'NO_COMMENT_VALUE': NO_COMMENT_VALUE,
                                           'SLOT_VERSION_VALUE': SLOT_VERSION_VALUE,
                                           'slot_num': str(slot_num) } ))

    # write JSON file for slot
    #
    try:
        with open(slot_json_file, mode="w", encoding="utf-8") as slot_file_fp:
            slot_file_fp.write(json.dumps(slot_json, ensure_ascii=True, indent=4))
            slot_file_fp.write('\n')

            # close slot file
            #
            # NOTE: We explicitly manage the close because we just did a write
            #       and we want to catch the case where a write buffer may have
            #       not been fully flushed to the file.
            #
            try:
                slot_file_fp.close()

            except OSError as errcode:
                ioccc_last_errmsg = f'ERROR: {me}: failed to close: {slot_json_file} failed: <<{errcode}>>'
                error(f'{me}: close writing for slot_json_file: {slot_json_file} '
                      f'failed: <<{errcode}>>')
                return False

    except OSError as errcode:
        ioccc_last_errmsg = f'ERROR: failed to write out slot file: {slot_json_file} failed: <<{errcode}>>'
        error(f'{me}: open for slot_json_file: {slot_json_file} failed: <<{errcode}>>')
        return False

    # firewall - slot.json must be a non-empty read/write file
    #
    if not Path(slot_json_file).exists() or not Path(slot_json_file).is_file() or \
       not os.access(slot_json_file, os.R_OK) or not os.access(slot_json_file, os.W_OK) or \
       os.path.getsize(slot_json_file) <= 0:
        ioccc_last_errmsg = f'ERROR: {me}: slot.json file was not setup correctly: {slot_json_file}'
        error(f'{me}: slot.json file was not setup correctly: {slot_json_file}')
        return False

    ########################
    # slot lock file setup #
    ########################

    # determine the slot lock file path
    #
    slot_lock_file = return_slot_lockfile(username, slot_num)
    if not slot_lock_file:
        ioccc_last_errmsg = f'ERROR: {me}: return_slot_lockfile failed'
        error(f'{me}: return_slot_lockfile failed')
        return False

    # be sure the lock file exists
    #
    try:
        Path(slot_lock_file).touch(mode=0o664, exist_ok=True)

    except OSError as errcode:
        ioccc_last_errmsg = (
            f'ERROR: {me}: failed touch (mode=0o664, exist_ok=True): '
            f'{slot_lock_file} failed: <<{errcode}>>')
        error(f'{me}: touch file_lock: {slot_lock_file} failed: <<{errcode}>>')
        return None

    # firewall - slot lock must be a read/write file
    #
    if not Path(slot_json_file).exists() or not Path(slot_json_file).is_file() or \
       not os.access(slot_json_file, os.R_OK) or not os.access(slot_json_file, os.W_OK):
        ioccc_last_errmsg = f'ERROR: {me}: slot lock file file was not setup correctly: {slot_json_file}'
        error(f'{me}: slot lock file was not setup correctly: {slot_json_file}')
        return False

    ##########
    # all OK #
    ##########

    debug(f'{me}: end: initialized username: {username} slot_num: {slot_num}')
    return True
#
# pylint: enable=too-many-return-statements
# pylint: enable=too-many-branches
# pylint: enable=too-many-statements


# pylint: disable=too-many-statements
# pylint: disable=too-many-branches
# pylint: disable=too-many-return-statements
#
def initialize_user_tree(username):
    """
    Initialize the directory tree for a given user

    We create the directory for the username if the directory does not exist.
    We create the slot for the username if the slot directory does not exist.
    We create the lock file for the slot it the lock file does not exist.
    We initialize the slot JSON file it the slot JSON file does not exist.

    NOTE: Because this may be called early, we cannot use HTML or other
          error carping delivery.  We only set last_excpt are return None.

    Given:
        username    IOCCC submit server username

    Returns:
        None ==> invalid slot number or invalid user directory
        != None ==> array of slot user data as a python dictionary

    NOTE: This function performs various canonical firewall checks on the username arg.
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - canonical firewall checks on the username arg
    #
    if not check_username_arg(username):

        # The check_username_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a username firewall check failure.
        #
        return None

    # setup
    #
    if not lookup_username(username):
        debug(f'{me}: lookup_username failed for username: {username}')
        return None
    user_dir = return_user_dir_path(username)
    if not user_dir:
        debug(f'{me}: return_user_dir_path failed for username: {username}')
        return None
    umask(0o022)

    # be sure the user directory exists
    #
    if not Path(user_dir).is_dir():
        info(f'{me}: about to initialize user directory tree for username: {username}')
    try:
        makedirs(user_dir, mode=0o2770, exist_ok=True)
    except OSError as errcode:
        ioccc_last_errmsg = f'ERROR: {me}: cannot form user directory for username: {username} failed: <<{errcode}>>'
        return None

    # process each slot for this user
    #
    slots = [None] * (MAX_SUBMIT_SLOT+1)
    for slot_num in range(0, MAX_SUBMIT_SLOT+1):

        # determine the slot directory
        #
        slot_dir = return_slot_dir_path(username, slot_num)
        if not slot_dir:
            error(f'{me}: return_slot_dir_path failed for username: {username} slot_num: {slot_num}')
            return None

        # be sure the slot directory exits
        #
        try:
            makedirs(slot_dir, mode=0o2770, exist_ok=True)
        except OSError as errcode:
            ioccc_last_errmsg = f'ERROR: {me}: cannot form slot directory: {slot_dir} failed: <<{errcode}>>'
            error(f'{me}: make directory for slot_dir: {slot_dir} '
                  f'failed: <<{errcode}>>')
            return None

        # Lock the slot
        #
        # This will create the lock file if needed.
        #
        slot_lock_fd = lock_slot(username, slot_num)
        if not slot_lock_fd:
            error(f'{me}: lock_slot failed for username: {username} slot_num: {slot_num}')
            return None

        # read the JSON file for the user's slot
        #
        # NOTE: We initialize the slot JSON file if the JSON file does not exist.
        #
        slot_json_file = return_slot_json_filename(username, slot_num)
        if not slot_json_file:
            error(f'{me}: return_slot_json_filename failed for username: {username} slot_num: {slot_num}')
            unlock_slot()
            return None
        try:
            with open(slot_json_file, "r", encoding="utf-8") as slot_file_fp:

                # obtain slot JSON file as a python dictionary
                #
                slots[slot_num] = json.load(slot_file_fp)

                # validate slot JSON file as a python dictionary
                #
                err_msg = validate_slot_dict_nolock(slots[slot_num], username, slot_num)
                if err_msg:
                    error(f'{me}: {err_msg} for: username: {username} slot_num: {slot_num}')
                    unlock_slot()
                    return None

        except OSError:
            debug(f'{me}: forming new slot file for username: {username} slot_num: {slot_num} '
                  f'slot_json_file: {slot_json_file}')

            # setup the JSON slot using the template
            #
            t = Template(EMPTY_JSON_SLOT_TEMPLATE)

            # initialize the slot JSON from the template
            #
            slots[slot_num] = json.loads(t.substitute( { 'NO_COMMENT_VALUE': NO_COMMENT_VALUE,
                                                         'SLOT_VERSION_VALUE': SLOT_VERSION_VALUE,
                                                         'slot_num': str(slot_num) } ))

            # validate slot JSON file as a python dictionary
            #
            err_msg = validate_slot_dict_nolock(slots[slot_num], username, slot_num)
            if err_msg:
                error(f'{me}: {err_msg} for: username: {username} slot_num: {slot_num}')
                unlock_slot()
                return None

            # update the JSON for the slot
            #
            try:
                with open(slot_json_file, mode="w", encoding="utf-8") as slot_file_fp:
                    slot_file_fp.write(json.dumps(slots[slot_num], ensure_ascii=True, indent=4))
                    slot_file_fp.write('\n')

                    # close slot file
                    #
                    # NOTE: We explicitly manage the close because we just did a write
                    #       and we want to catch the case where a write buffer may have
                    #       not been fully flushed to the file.
                    #
                    try:
                        slot_file_fp.close()

                    except OSError as errcode:
                        ioccc_last_errmsg = (
                            f'ERROR: {me}: failed to close: {slot_json_file} '
                            f'failed: <<{errcode}>>')
                        error(f'{me}: close writing for slot_json_file: {slot_json_file} '
                              f'failed: <<{errcode}>>')
                        unlock_slot()
                        return None

            except OSError as errcode:
                ioccc_last_errmsg = (
                    f'ERROR: {me}: unable to write JSON slot file: {slot_json_file} '
                    f'failed: <<{errcode}>>')
                error(f'{me}: open for writing slot_json_file: {slot_json_file} failed: <<{errcode}>>')
                unlock_slot()
                return None

        # Unlock the slot
        #
        unlock_slot()

    # Return success
    #
    debug(f'{me}: end: directory tree ready for username: {username}')
    return slots
#
# pylint: enable=too-many-statements
# pylint: enable=too-many-branches
# pylint: enable=too-many-return-statements


# pylint: disable=too-many-return-statements
#
def get_all_json_slots(username):
    """
    read the user data for all slots for a given user.

    Given:
        username    IOCCC submit server username

    Returns:
        None ==> invalid slot number or invalid user directory
        != None ==> array of slot user data as a python dictionary

    NOTE: This function performs various canonical firewall checks on the username arg.
    """

    # setup
    #
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - canonical firewall checks on the username arg
    #
    if not check_username_arg(username):

        # The check_username_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a username firewall check failure.
        #
        return None

    # setup
    #
    umask(0o022)

    # firewall - username arg must be a string
    #
    if not isinstance(username, str):
        info(f'{me}: username arg is not a string')
        return None

    # validate username
    #
    if not lookup_username(username):
        debug(f'{me}: lookup_username failed for username: {username}')
        return None
    user_dir = return_user_dir_path(username)
    if not user_dir:
        error(f'{me}: return_user_dir_path failed for username: {username}')
        return None

    # initialize the user tree in case this is a new user
    #
    # NOTE: The call to initialize_user_tree() will lock each slot while
    #       the slot is being processed.
    #
    slots = initialize_user_tree(username)
    if not slots:
        error(f'{me}: initialize_user_tree failed for username: {username}')
        return None

    # return slot information as a python dictionary
    #
    debug(f'{me}: end: returning all slots for username: {username}')
    return slots
#
# pylint: enable=too-many-return-statements


# pylint: disable=too-many-return-statements
# pylint: disable=too-many-locals
# pylint: disable=too-many-statements
# pylint: disable=too-many-branches
#
def update_slot(username, slot_num, submit_file):
    """
    Update a given slot for a given user with a new file

    Given:
        username      IOCCC submit server username
        slot_num      slot number for a given username
        submit_file   filename stored under a given slot

    Returns:
        True        recorded and reported the SHA256 hash of submit_file
        False       some error was detected

    NOTE: This function performs various canonical firewall checks on the username arg.

    NOTE: This function performs various canonical firewall checks on the slot_num arg.
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - canonical firewall checks on the username arg
    #
    if not check_username_arg(username):

        # The check_username_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a username firewall check failure.
        #
        return False

    # firewall - canonical firewall checks on the slot_num arg
    #
    if not check_slot_num_arg(slot_num):

        # The check_slot_num_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a slot_num firewall check failure.
        #
        return False

    # initialize user if needed
    #
    slots = initialize_user_tree(username)
    if not slots:
        error(f'{me}: initialize_user_tree failed for username: {username}')
        return False

    # determine the slot directory
    #
    slot_dir = return_slot_dir_path(username, slot_num)
    if not slot_dir:
        error(f'{me}: return_slot_dir_path failed for username: {username} slot_num: {slot_num}')
        unlock_slot()
        return False

    # open the file
    #
    try:
        with open(submit_file, "rb") as file_fp:
            result = hashlib.sha256(file_fp.read())

            # paranoia
            #
            if not result or len(result.hexdigest()) != SHA256_HEXLEN:
                error(f'{me}: invalid SHA-256 hash return')
                return False

    except OSError as errcode:
        ioccc_last_errmsg = (
            f'ERROR: {me}: failed to open for username: {username} '
            f'submit_file: {submit_file} failed: <<{errcode}>>')
        error(f'{me}: open for username: {username} slot_num: {slot_num} submit_file: {submit_file} '
              f'failed: <<{errcode}>>')
        return False

    # lock the slot because we are about to change it
    #
    slot_lock_fd = lock_slot(username, slot_num)
    if not slot_lock_fd:
        error(f'{me}: lock_slot failed for username: {username} slot_num: {slot_num}')
        return False

    # read the JSON file for the user's slot
    #
    slot_json_file = return_slot_json_filename(username, slot_num)
    if not slot_json_file:
        error(f'{me}: return_slot_json_filename failed for username: {username} slot_num: {slot_num}')
        unlock_slot()
        return False
    slot_dict = read_json_file_nolock(slot_json_file)
    if not slot_dict:
        error(f'{me}: read_json_file_nolock failed for username: {username} slot_num: {slot_num} '
              f'slot_json_file: {slot_json_file}')
        unlock_slot()
        return False

    # If the slot previously saved file that has a different name than the new file,
    # then remove the old file
    #
    old_file = return_submit_path(slot_dict, username, slot_num)
    if old_file:

        # remove previously saved file
        #
        if submit_file != old_file and os.path.isfile(old_file):
            try:
                os.remove(old_file)
            except OSError as errcode:
                ioccc_last_errmsg = (
                    f'ERROR: {me}: failed to remove old file: {old_file} from slot: {slot_num} '
                    f'failed: <<{errcode}>>')
                error(f'{me}: os.remove({old_file} for username: {username} slot_num: {slot_num} '
                      f'failed: <<{errcode}>>')
                unlock_slot()
                return False

    # record and report SHA256 hash of file
    #
    slot_dict['status'] = 'Uploaded file into slot'
    slot_dict['filename'] = os.path.basename(submit_file)
    slot_dict['length'] = os.path.getsize(submit_file)
    slot_dict['date'] = re.sub(r'\+00:00 ', ' ', f'{datetime.now(timezone.utc)} UTC')
    slot_dict['SHA256'] = result.hexdigest()

    # save JSON data for the slot
    #
    slot_json_file = return_slot_json_filename(username, slot_num)
    if not slot_json_file:
        error(f'{me}: return_slot_json_filename failed for username: {username} slot_num: {slot_num}')
        unlock_slot()
        return False
    if not write_slot_json_nolock(slot_json_file, slot_dict):
        error(f'{me}: write_slot_json_nolock failed for username: {username} slot_num: {slot_num}')
        unlock_slot()
        return False

    # unlock the slot and report success
    #
    unlock_slot()
    debug(f'{me}: end: updated slot for username: {username} slot_num: {slot_num}')
    return True
#
# pylint: enable=too-many-return-statements
# pylint: enable=too-many-locals
# pylint: enable=too-many-statements
# pylint: enable=too-many-branches


# pylint: disable=too-many-return-statements
#
def update_slot_status(username, slot_num, status):
    """
    Update the status comment for a given user's slot

    Given:
        username    IOCCC submit server username
        slot_num    slot number for a given username
        status      the new status string for the slot

    Returns:
        True        status updated
        False       some error was detected

    NOTE: This function performs various canonical firewall checks on the username arg.

    NOTE: This function performs various canonical firewall checks on the slot_num arg.
    """

    # setup
    #
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - canonical firewall checks on the username arg
    #
    if not check_username_arg(username):

        # The check_username_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a username firewall check failure.
        #
        return False

    # firewall - canonical firewall checks on the slot_num arg
    #
    if not check_slot_num_arg(slot_num):

        # The check_slot_num_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a slot_num firewall check failure.
        #
        return False

    # firewall - check args
    #
    if not isinstance(status, str):
        error(f'{me}: status arg is not a string')
        return False

    # must be a valid user
    #
    if not lookup_username(username):
        debug(f'{me}: lookup_username failed for username: {username}')
        return False
    slot_json_file = return_slot_json_filename(username, slot_num)
    if not slot_json_file:
        debug(f'{me}: return_slot_json_filename failed')
        return False

    # lock the slot because we are about to change it
    #
    slot_lock_fd = lock_slot(username, slot_num)
    if not slot_lock_fd:
        debug(f'{me}: lock_slot failed')
        return False

    # read the JSON file for the user's slot
    #
    slot_dict = read_json_file_nolock(slot_json_file)
    if not slot_dict:
        error(f'{me}: read_json_file_nolock failed for username: {username} slot_num: {slot_num} '
              f'slot_json_file: {slot_json_file}')
        unlock_slot()
        return False

    # update the status
    #
    slot_dict['status'] = status

    # save JSON data for the slot
    #
    slot_json_file = return_slot_json_filename(username, slot_num)
    if not slot_json_file:
        error(f'{me}: return_slot_json_filename failed for username: {username} slot_num: {slot_num}')
        unlock_slot()
        return False
    if not write_slot_json_nolock(slot_json_file, slot_dict):
        error(f'{me}: write_slot_json_nolock failed for username: {username} slot_num: {slot_num}')
        unlock_slot()
        return False

    # unlock the slot and report success
    #
    unlock_slot()
    debug(f'{me}: end: updated slot status for username: {username} slot_num: {slot_num}')
    return True
#
# pylint: enable=too-many-return-statements


# pylint: disable=too-many-return-statements
#
def update_slot_status_if_submit(username, slot_num, status, submit_file):
    """
    Update the status comment for a given user's slot, if and only if
    the submit_file matches the slot's filename.

    Given:
        username    IOCCC submit server username
        slot_num    slot number for a given username
        status      the new status string for the slot
        submit_file   filename stored under a given slot

    Returns:
        True        status updated
        False       some error was detected

    NOTE: This function performs various canonical firewall checks on the username arg.

    NOTE: This function performs various canonical firewall checks on the slot_num arg.
    """

    # setup
    #
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - canonical firewall checks on the username arg
    #
    if not check_username_arg(username):

        # The check_username_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a username firewall check failure.
        #
        return False

    # firewall - canonical firewall checks on the slot_num arg
    #
    if not check_slot_num_arg(slot_num):

        # The check_slot_num_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a slot_num firewall check failure.
        #
        return False

    # firewall - check args
    #
    if not isinstance(status, str):
        error(f'{me}: status arg is not a string')
        return False
    if not isinstance(submit_file, str):
        error(f'{me}: submit_file arg is not a string')
        return False

    # must be a valid user
    #
    if not lookup_username(username):
        debug(f'{me}: lookup_username failed for username: {username}')
        return False
    slot_json_file = return_slot_json_filename(username, slot_num)
    if not slot_json_file:
        debug(f'{me}: return_slot_json_filename failed')
        return False

    # lock the slot because we are about to change it
    #
    slot_lock_fd = lock_slot(username, slot_num)
    if not slot_lock_fd:
        debug(f'{me}: lock_slot failed')
        return False

    # read the JSON file for the user's slot
    #
    slot_dict = read_json_file_nolock(slot_json_file)
    if not slot_dict:
        error(f'{me}: read_json_file_nolock failed for username: {username} slot_num: {slot_num} '
              f'slot_json_file: {slot_json_file}')
        unlock_slot()
        return False

    # check the slot filename for a match against submit_file
    #
    if not 'filename' in slot_dict:
        error(f'{me}: missing filename for username: {username} slot_num: {slot_num} '
              f'slot_json_file: {slot_json_file}')
        unlock_slot()
        return False
    if submit_file != slot_dict['filename']:

        # slot was updated before we could change the status.  The status arg applies to
        # a different (previous submit file), so we simply and silently drop this status change
        # without any error reporting.
        #
        unlock_slot()
        return True

    # update the status
    #
    slot_dict['status'] = status

    # save JSON data for the slot
    #
    slot_json_file = return_slot_json_filename(username, slot_num)
    if not slot_json_file:
        error(f'{me}: return_slot_json_filename failed for username: {username} slot_num: {slot_num}')
        unlock_slot()
        return False
    if not write_slot_json_nolock(slot_json_file, slot_dict):
        error(f'{me}: write_slot_json_nolock failed for username: {username} slot_num: {slot_num}')
        unlock_slot()
        return False

    # unlock the slot and report success
    #
    unlock_slot()
    debug(f'{me}: end: updated slot status username: {username} slot_num: {slot_num} for submit file: {submit_file}')
    return True
#
# pylint: enable=too-many-return-statements


def read_json_file_nolock(json_file):
    """
    Return the contents of a JSON file as a python dictionary

    Given:
        json_file   JSON file to read

    Returns:
        != None     JSON file contents as a python dictionary
        None        unable to read JSON file

    WARNING: This function does NOT lock.  The caller should lock as needed.
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # try to read JSON contents
    #
    try:
        with open(json_file, 'r', encoding='utf-8') as j_fp:

            # return slot information as a python dictionary
            #
            try:
                slot_dict = json.load(j_fp)
            except json.JSONDecodeError:
                ioccc_last_errmsg = f'ERROR: {me}: invalid JSON in file: {json_file}'
                error(f'{me}:  invalid JSON in file: {json_file}')
                return []
            except UnicodeDecodeError:
                ioccc_last_errmsg = f'ERROR: {me}: invalid Unicode data in file: {json_file}'
                error(f'{me}:  invalid Unicode data in file: {json_file}')
                return []
            debug(f'{me}: end: return python dictionary for JSON file: {json_file}')
            return slot_dict

    except OSError as errcode:
        ioccc_last_errmsg = f'ERROR: {me}: cannot open JSON in: {json_file} failed: <<{errcode}>>'
        error(f'{me}: read JSON for json_file: {json_file} '
              f'failed: <<{errcode}>>')
        return []


# pylint: disable=too-many-statements
# pylint: disable=too-many-branches
# pylint: disable=too-many-return-statements
#
def read_state():
    """
    Read the state file for the open and close dates

    Returns:
        == None, None
                Unable to open the state file, or
                Unable to read the state file, or
                Unable to parse the JSON in the state file,
                state file missing the open date, or
                open date string is not in a valid datetime format, or
                state file missing the close date, or
                close date string is not in a valid datetime in DATETIME_USEC_FORMAT format
        != None, open_datetime, close_datetime in datetime in DATETIME_USEC_FORMAT format
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # Lock the state file
    #
    state_lock_fd = ioccc_file_lock(STATE_FILE_LOCK)
    if not state_lock_fd:
        error(f'{me}: failed to lock file for STATE_FILE_LOCK: {STATE_FILE_LOCK}')
        return None, None

    # If there is no state file, or if the state file is empty, copy it from the initial state file
    #
    if not os.path.isfile(STATE_FILE) or os.path.getsize(STATE_FILE) <= 0:
        try:
            shutil.copy2(INIT_STATE_FILE, STATE_FILE, follow_symlinks=True)

        except OSError as errcode:
            ioccc_last_errmsg = f'ERROR: {me}: cannot cp -p {INIT_STATE_FILE} {STATE_FILE} failed: <<{errcode}>>'
            error(f'{me}: cp -p {INIT_STATE_FILE} {STATE_FILE} failed: <<{errcode}>>')
            ioccc_file_unlock()
            return None, None

    # read the state
    #
    state = read_json_file_nolock(STATE_FILE)

    # Unlock the state file
    #
    ioccc_file_unlock()

    # detect if we were unable to read the state file
    #
    if not state:
        ioccc_last_errmsg = f'Warning: {me}: unable to read the state file: {STATE_FILE}'
        warning(f'{me}: unable to read the state file: {STATE_FILE}')
        return None, None

    # firewall check state file no_comment
    #
    if not 'no_comment' in state:
        ioccc_last_errmsg = f'ERROR: {me}: username is missing from state file'
        error(f'{me}: username is missing from state file')
        return None, None
    if not isinstance(state['no_comment'], str):
        ioccc_last_errmsg = f'ERROR: {me}: no_comment is not a string in state file'
        error(f'{me}: no_comment not a string for STATE_FILE: {STATE_FILE}')
        return None, None
    if state['no_comment'] != NO_COMMENT_VALUE:
        ioccc_last_errmsg = f'ERROR: {me}: invalid JSON no_comment in state file'
        error(f'{me}: invalid JSON no_comment for STATE_FILE: {STATE_FILE} '
              f'state["no_comment"]: {state["no_comment"]} != '
              f'NO_COMMENT_VALUE: {NO_COMMENT_VALUE}')
        return None, None

    # firewall check state file state_JSON_format_version
    #
    if not 'state_JSON_format_version' in state:
        ioccc_last_errmsg = f'ERROR: {me}: state_JSON_format_version is missing from state file'
        error(f'{me}: state_JSON_format_version is missing from state file')
        return None, None
    if not isinstance(state['state_JSON_format_version'], str):
        ioccc_last_errmsg = f'ERROR: {me}: state_JSON_format_version is not a string in state file'
        error(f'{me}: state_JSON_format_version not a string for STATE_FILE: {STATE_FILE}')
        return None, None
    if state['state_JSON_format_version'] != STATE_VERSION_VALUE:
        ioccc_last_errmsg = f'ERROR: {me}: invalid JSON state_JSON_format_version in state file'
        error(f'{me}: invalid state_JSON_format_version for '
              f'STATE_FILE: {STATE_FILE} state_JSON_format_version: <<{state["state_JSON_format_version"]}>> != '
              f'STATE_VERSION_VALUE: {STATE_VERSION_VALUE}')
        unlock_slot()
        return None, None

    # convert open date string into a datetime value
    #
    if not 'open_date' in state:
        ioccc_last_errmsg = f'ERROR: {me}: open_date is missing from state file'
        error(f'{me}: open_date is missing from state file')
        return None, None
    if not isinstance(state['open_date'], str):
        ioccc_last_errmsg = f'ERROR: {me}: state file open_date is not a string'
        error(f'{me}: open_date is not a string for STATE_FILE: {STATE_FILE}')
        return None, None
    try:
        open_datetime = datetime.strptime(state['open_date'], DATETIME_USEC_FORMAT)
    except ValueError as errcode:
        ioccc_last_errmsg = (
            f'ERROR: {me}: state file open_date is not in proper datetime '
            f'format: <<{state["open_date"]}>> failed: <<{errcode}>>')
        error(f'{me}: datetime.strptime of open_date for STATE_FILE: {STATE_FILE} '
              f'open_date: {state["open_date"]} failed: <<{errcode}>>')
        return None, None

    # convert close date string into a datetime value
    #
    if not 'close_date' in state:
        ioccc_last_errmsg = f'ERROR: {me}: close_date is missing from state file'
        error(f'{me}: close_date is missing from state file')
        return None, None
    if not isinstance(state['close_date'], str):
        ioccc_last_errmsg = f'ERROR: {me}: state file close_date is not a string'
        error(f'{me}: close_date is not a string for STATE_FILE: {STATE_FILE}')
        return None, None
    try:
        close_datetime = datetime.strptime(state['close_date'], DATETIME_USEC_FORMAT)
    except ValueError as errcode:
        ioccc_last_errmsg = (
            f'ERROR: {me}: state file close_date is not in proper datetime '
            f'format: <<{state["close_date"]}>>')
        error(f'{me}: datetime.strptime of close_date for STATE_FILE: {STATE_FILE} '
              f'close_date: {state["close_date"]} failed: <<{errcode}>>')
        return None, None

    # return open and close dates
    #
    debug(f'{me}: end: returning open and close dates')
    return open_datetime, close_datetime
#
# pylint: enable=too-many-statements
# pylint: enable=too-many-branches
# pylint: enable=too-many-return-statements


def update_state(open_date, close_date):
    """
    Update contest dates in the JSON state file

    Given:
        open_date   IOCCC open date as a string in DATETIME_USEC_FORMAT format
        close_date  IOCCC close date as a string in DATETIME_USEC_FORMAT format

    Return:
        True        json state file was successfully written
        False       unable to update json state file
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')
    write_sucessful = True

    # firewall - open_date must be a string in DATETIME_USEC_FORMAT format
    #
    if not isinstance(open_date, str):
        ioccc_last_errmsg = f'ERROR: {me}: open_date is not a string'
        error(f'{me}: open_date arg is not a string')
        return False
    try:
        # pylint: disable=unused-variable
        open_datetime = datetime.strptime(open_date, DATETIME_USEC_FORMAT)
    except ValueError as errcode:
        ioccc_last_errmsg = (
            f'ERROR: {me}: open_date arg not in proper datetime format '
            f'failed: <<{errcode}>>')
        error(f'{me}: open_date arg not in proper datetime format '
              f'failed: <<{errcode}>>')
        return False

    # firewall - close_date must be a string in DATETIME_USEC_FORMAT format
    #
    if not isinstance(close_date, str):
        ioccc_last_errmsg = f'ERROR: {me}: close_date is not a string'
        error(f'{me}: close_date arg is not a string')
        return False
    try:
        # pylint: disable=unused-variable
        close_datetime = datetime.strptime(close_date, DATETIME_USEC_FORMAT)
    except ValueError as errcode:
        ioccc_last_errmsg = (
            f'ERROR: {me}: state file close_date is not in proper datetime format '
            f'format: <<{close_date}>> failed: <<{errcode}>>')
        error(f'{me}: datetime.strptime of close_date arg: {close_date} format '
              f'failed: <<{errcode}>>')
        return False

    # Lock the state file
    #
    state_lock_fd = ioccc_file_lock(STATE_FILE_LOCK)
    if not state_lock_fd:
        error(f'{me}: failed to lock file for STATE_FILE_LOCK: {STATE_FILE_LOCK}')
        return False

    # write JSON data into the state file
    #
    try:
        with open(STATE_FILE, 'w', encoding='utf-8') as sf_fp:
            t = Template(DEFAULT_JSON_STATE_TEMPLATE)
            state = json.loads(t.substitute( { 'NO_COMMENT_VALUE': NO_COMMENT_VALUE,
                                               'STATE_VERSION_VALUE': STATE_VERSION_VALUE,
                                               'OPEN_DATE': open_date,
                                               'CLOSE_DATE': close_date } ))
            sf_fp.write(json.dumps(state,
                                   ensure_ascii = True,
                                   indent = 4))
            sf_fp.write('\n')

            # close state file
            #
            # NOTE: We explicitly manage the close because we just did a write
            #       and we want to catch the case where a write buffer may have
            #       not been fully flushed to the file.
            #
            try:
                sf_fp.close()
            except OSError as errcode:
                error(f'{me}: close writing for STATE_FILE: {STATE_FILE} '
                      f'failed: <<{errcode}>>')
                ioccc_last_errmsg = f'ERROR: {me}: failed to close: {STATE_FILE} failed: <<{errcode}>>'
                write_sucessful = False
                # fall thru

    except OSError:
        ioccc_last_errmsg = f'ERROR: {me}: cannot write state file: {STATE_FILE}'
        write_sucessful = False
        # fall thru

    # Unlock the state file
    #
    ioccc_file_unlock()

    # return success
    #
    debug(f'{me}: end: update_state: {write_sucessful}')
    return write_sucessful


def contest_is_open(user_dict):
    """
    Determine if the IOCCC is open.

    Given:
        user_dict    user information for username as a python dictionary

    Return:
        != None     Contest is open,
                    return close_datetime in datetime in DATETIME_USEC_FORMAT format
        None        Contest is closed

    NOTE: If the user may ignore the date, and we have a close date, then we will
          always assume the contest is open for that user.  This is to allow
          the user to test the server before the contest opens for others.
    """

    # setup
    #
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')
    now = datetime.now(timezone.utc)

    # firewall check the user information
    #
    if not validate_user_dict_nolock(user_dict):
        error(f'{me}: validate_user_dict_nolock failed')
        return None

    # paranoia - must have ignore_date in user_dict
    #
    if not 'ignore_date' in user_dict:
        error(f'{me}: ignore_date is missing from user_dict')
        return False

    # obtain open and close dates as date strings
    #
    open_datetime, close_datetime = read_state()
    if not open_datetime or not close_datetime:
        debug(f'{me}: end: no open and close dates')
        return None

    # For users that mayignore the date, the contest is always open,
    # even if we are outside the contest open-close internal.
    #
    if user_dict['ignore_date']:
        debug(f'{me}: end: ignoring close date for username: {user_dict["username"]}')
        return close_datetime

    # determine if the contest is open now
    #
    if now.timestamp() >= open_datetime.timestamp():
        if now.timestamp() < close_datetime.timestamp():
            debug(f'{me}: end: contest is open')
            return close_datetime
    debug(f'{me}: end: contest is closed')
    return None


def return_secret():
    """
    Read a application secret key from the SECRET_FILE, or generate it on the fly.

    We try will read the 1st line of the SECRET_FILE, ignoring the newlines.
    If we cannot, we will generate on a secret the fly for testing using a UUID type 4.

    Generating a secret the fly exception case may not work well in production as
    different instances of this app will have different secrets.

    Returns:
        secret randomly generated string or about 64 bytes in length.
    """

    # setup
    #
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # Try read the 1st line of the SECRET_FILE, ignoring the newline:
    #
    try:
        with open(SECRET_FILE, 'r', encoding='utf-8') as secret:
            secret_key = secret.read().rstrip()

    except OSError as errcode:
        # FALLBACK: generate on a secret the fly for testing
        #
        # IMPORTANT: This exception case may not work well in production as
        #            different instances of this app will have different secrets.
        #
        warning(f'{me}: open SECRET_FILE: {SECRET_FILE} failed: <<{errcode}>>')
        warning(f'{me}: generating secret_key on the fly: failed to obtain it from SECRET_FILE: {SECRET_FILE}')
        secret_key = f'{uuid.uuid4()}//{randrange(1000)}.{randrange(1000)}'
        # fall thru

    # paranoia - not a string
    #
    if not isinstance(secret_key, str):
        warning(f'{me}: generating secret_key on the fly: non-string found in from SECRET_FILE: {SECRET_FILE}')
        secret_key = f'{uuid.uuid4()}/*{randrange(1000)}.{randrange(1000)}'
        # fall thru

    # paranoia - too short
    #
    elif len(secret_key) < MIN_SECRET_LEN:
        warning(f'{me}: generating secret_key on the fly: string too short in SECRET_FILE: {SECRET_FILE}')
        secret_key = f'{uuid.uuid4()}*/{randrange(1000)}.{randrange(1000)}'
        # fall thru

    # return secret key
    #
    debug(f'{me}: end: returning secret key')
    return secret_key


# pylint: disable=too-many-branches
# pylint: disable=too-many-statements
#
def setup_logger(logtype, dbglvl) -> None:
    """
    setup_logger - Setup the logging facility.

    Given:
        logtype      "stdout" ==> log to stdout,
                     "stderr" ==> log to stderr,
                     "syslog" ==> log via syslog,
                     "none" ==> do not log,
                     None ==> do not change the log state,
                     all other values ==> do not change the log state

        dbglvl      "dbg" ==> use logging.DEBUG,
                    "debug" ==> use logging.DEBUG,
                    "info" ==> use logging.INFO,
                    "warn" ==> use logging.WARNING,
                    "warning" ==> use logging.WARNING,
                    "error" ==> use logging.ERROR,
                    "crit" ==> use logging.CRITICAL,
                    "critical" ==> use logging.CRITICAL,
                     all other values ==> use logging.INFO

    NOTE: Until setup_logger(logtype) is called, ioccc_logger default None and no logging will occur.

    NOTE: The logtype is case insensitive, so "syslog", "Syslog", "SYSLOG" are treated the same.
    NOTE: The dbglvl is case insensitive, so "info", "Info", "INFO" are treated the same.
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_logger
    me = inspect.currentframe().f_code.co_name
    # We do NOT want to call debug start from this function because this function does the debug setup
    #no# debug(f'{me}: start')
    logging_level = logging.INFO

    # case: logtype is not a string (such as None) or unknown logtype string
    #
    if not logtype or not isinstance(logtype, str) or not logtype.lower() in {'stdout', 'stderr', 'syslog', 'none'}:

        # do not change the log state
        #
        return

    # case: logtype is "none"
    #
    if logtype.lower() == "none":

        # do not log
        #
        ioccc_logger = None
        return

    # set the debug level based on dbglvl
    #
    # We default to logging.INFO is dbglvl is not a string (such as None) or unknown dbglvl string
    #
    if isinstance(dbglvl, str):
        # pylint: disable-next=consider-using-in
        if dbglvl.lower() == "dbg" or dbglvl.lower() == "debug":
            logging_level = logging.DEBUG
        elif dbglvl.lower() == "info":
            logging_level = logging.INFO
        # pylint: disable-next=consider-using-in
        elif dbglvl.lower() == "warn" or dbglvl.lower() == "warning":
            logging_level = logging.WARNING
        # pylint: disable-next=consider-using-in
        elif dbglvl.lower() == "err" or dbglvl.lower() == "error":
            logging_level = logging.ERROR
        # pylint: disable-next=consider-using-in
        elif dbglvl.lower() == "crit" or dbglvl.lower() == "critical":
            logging_level = logging.CRITICAL

    # create the logger, which will change the state
    #
    # As this point we know that that logtype of an allowed string.
    #
    my_logger = logging.getLogger('ioccc')

    # paranoia
    #
    if not my_logger:
        print(f'ERROR via print: logging.getLogger returned None for logtype: {logtype}')
        return

    # case: logtype is "stdout"
    #
    # log to stdout
    #
    if logtype.lower() == "stdout":

        # set logging format
        #
        formatter = logging.Formatter(
                        '%(asctime)s.%(msecs)03d: %(name)s: %(levelname)s: %(message)s',
                        datefmt='%Y-%m-%d %H:%M:%S')

        # setup stdout logging handler
        #
        stdout_handler = logging.StreamHandler(sys.stdout)
        stdout_handler.setLevel(logging_level)
        stdout_handler.setFormatter(formatter)

        # configure the logger
        #
        # There is BUG in logging where logging requires
        # an additional call to the logging.basicConfig function.
        #
        # To avoid duplicate messages, we do not call:
        #
        #   my_logger.addHandler(stdout_handler)
        #
        logging.basicConfig(level=logging_level, handlers=[stdout_handler])

    # case: logtype is "stderr"
    #
    # log to stderr
    #
    if logtype.lower() == "stderr":

        # set logging format
        #
        formatter = logging.Formatter(
                        '%(asctime)s.%(msecs)03d: %(name)s: %(levelname)s: %(message)s',
                        datefmt='%Y-%m-%d %H:%M:%S')

        # setup stderr logging handler
        #
        stderr_handler = logging.StreamHandler(sys.stderr)
        stderr_handler.setLevel(logging_level)
        stderr_handler.setFormatter(formatter)

        # configure the logger
        #
        # There is BUG in logging where logging requires
        # an additional call to the logging.basicConfig function.
        #
        # To avoid duplicate messages, we do not call:
        #
        #   my_logger.addHandler(stderr_handler)
        #
        logging.basicConfig(level=logging_level, handlers=[stderr_handler])

    # case: logtype is "syslog"
    #
    # log via syslog local5 facility
    #
    if logtype.lower() == "syslog":

        # set logging format
        #
        formatter = logging.Formatter(
                        '%(asctime)s.%(msecs)03d: %(name)s: %(levelname)s: %(message)s',
                        datefmt='%Y-%m-%d %H:%M:%S')

        # determine the logging address
        #
        if Path("/var/run/syslog").exists():

            # macOS
            #
            log_address = "/var/run/syslog"

        elif Path("/run/systemd/journal/dev-log").exists():

            # Linux and related friends
            #
            log_address = "/run/systemd/journal/dev-log"

        elif Path("/dev/log").exists():

            # Linux and related friends symlink
            #
            log_address = "/dev/log"

        elif Path("/var/run/log").exists():

            # FreeBSD and NetBSD and related friends
            #
            log_address = "/var/run/log"

        else:

            # unknown - use /dev/null
            #
            log_address = "/dev/null"

        # setup the syslog handler
        #
        syslog_handler = SysLogHandler(address = log_address,
                                       facility = SysLogHandler.LOG_LOCAL5)
        syslog_handler.setLevel(logging_level)
        syslog_handler.setFormatter(formatter)

        # add the file logging handler to the logger
        #
        # To avoid duplicate messages, we do not call:
        #
        #   my_logger.addHandler(syslog_handler)
        #
        logging.basicConfig(level=logging_level, handlers=[syslog_handler])

    # more paranoia
    #
    if not my_logger:
        print(f'ERROR via print: about to return with a None my_logger for logtype: {logtype}')
        return

    # save the newly configured logger
    #
    debug(f'{me}: end: configured logger')
    ioccc_logger = my_logger
#
# pylint: enable=too-many-branches
# pylint: enable=too-many-statements


def debug(msg, *args, **kwargs):
    """
    Write a DEBUG message or not depending on ioccc_logger

    If not ioccc_logger, then
        do not log (do nothing),
    else
        Use ioccc_logger as a logging facility that was setup  by setup_logger(Bool)
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    # We do NOT want to call debug start from this function because of recursion
    #no# debug(f'{me}: start')

    if ioccc_logger:
        try:
            ioccc_logger.debug(msg, *args, **kwargs)

        except OSError as errcode:
            ioccc_last_errmsg = f'ERROR: {me}: ioccc_logger.debug failed, failed: <<{errcode}>>'


def dbg(msg, *args, **kwargs):
    """
    Write a DEBUG message if we have called setup_logger to setup ioccc_logger.

    If not ioccc_logger, then
        do not log (do nothing),
    else
        Use ioccc_logger as a logging facility that was setup  by setup_logger(Bool)
    """

    # setup
    #
    # We do NOT want to call debug start from this function because this function does the debug setup
    #no# me = inspect.currentframe().f_code.co_name
    #no# debug(f'{me}: start')

    debug(msg, *args, **kwargs)


def info(msg, *args, **kwargs):
    """
    Write a INFO message if we have called setup_logger to setup ioccc_logger.

    If not ioccc_logger, then
        do not log (do nothing),
    else
        Use ioccc_logger as a logging facility that was setup  by setup_logger(Bool)
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    # pylint: disable-next=global-statement,global-variable-not-assigned
    global ioccc_logger
    me = inspect.currentframe().f_code.co_name
    # We do NOT want to call debug start from this function because of recursion
    #no# debug(f'{me}: start')

    if ioccc_logger:
        try:
            ioccc_logger.info(msg, *args, **kwargs)

        except OSError as errcode:
            ioccc_last_errmsg = f'ERROR: {me}: ioccc_logger.info failed, failed: <<{errcode}>>'


def warning(msg, *args, **kwargs):
    """
    Write a WARNING message if we have called setup_logger to setup ioccc_logger.

    If not ioccc_logger, then
        do not log (do nothing),
    else
        Use ioccc_logger as a logging facility that was setup  by setup_logger(Bool)
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    # We do NOT want to call debug start from this function because of recursion
    #no# debug(f'{me}: start')

    if ioccc_logger:
        try:
            ioccc_logger.warning(msg, *args, **kwargs)

        except OSError as errcode:
            ioccc_last_errmsg = f'ERROR: {me}: ioccc_logger.warning failed, failed: <<{errcode}>>'


def warn(msg, *args, **kwargs):
    """
    Write a WARNING message if we have called setup_logger to setup ioccc_logger.

    If not ioccc_logger, then
        do not log (do nothing),
    else
        Use ioccc_logger as a logging facility that was setup  by setup_logger(Bool)
    """

    # setup
    #
    # We do NOT want to call debug start from this function because this function does the debug setup
    #no# me = inspect.currentframe().f_code.co_name
    #no# debug(f'{me}: start')

    warning(msg, *args, **kwargs)


def error(msg, *args, **kwargs):
    """
    Write an ERROR message if we have called setup_logger to setup ioccc_logger.

    If not ioccc_logger, then
        do not log (do nothing),
    else
        Use ioccc_logger as a logging facility that was setup  by setup_logger(Bool)
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    # We do NOT want to call debug start from this function because of recursion
    #no# debug(f'{me}: start')

    if ioccc_logger:
        try:
            ioccc_logger.error(msg, *args, **kwargs)

        except OSError as errcode:
            ioccc_last_errmsg = f'ERROR: {me}: ioccc_logger.error failed, failed: <<{errcode}>>'


def sha256_file(filename):
    """
    Compute the SHA256 hash as a ASCII HEX digest string.

    We compute the SHA256 hash in an efficient way, for Python 3 version < 3.11.

        - Avoid character encoding and line-ending conversion issues.
        - Sequentially read it block by block and update the hash for each block.
        - Eliminate double buffering.
        - Use readinto() to avoid buffer churning.

    See this helpful comment by axschlepzig in stack overflow:

        https://stackoverflow.com/a/44873382/27339496

    Given:
        filename    path to a file to SHA256 hash

    Returns:
        None ==> filename does not exist, or
                 filename is not readable, or
                 unable to SHA256 hash the filename
        != None ==> SHA256 hash as a ASCII HEX digest string

    NOTE: This code assumes Python versions < 3.8 or later
          due to the assignment expression.  See the above URL
          for a version of the code that works with older python.

    WARNING: This function does NOT lock.  The caller should lock as needed.
    """

    # setup
    #
    # pylint: disable-next=global-statement
    global ioccc_last_errmsg
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # paranoia - if we don't have an ip address string
    #
    if not isinstance(str, filename):
        error(f'{me}: filename value is not a string')
        return None

    # prep to SHA256 hash
    #
    h  = hashlib.sha256()
    b  = bytearray(SHA25_BUFSIZE)
    mv = memoryview(b)

    # SHA256 hash is chunks
    #
    try:
        with open(filename, 'rb', buffering=0) as f:
            while n := f.readinto(mv):
                h.update(mv[:n])

    except OSError as errcode:
        ioccc_last_errmsg = f'Warning: {me}: cannot open file: {filename} for SHA256 hashing failed: <<{errcode}>>'
        warning(f'{me}: open for reading {filename} failed: <<{errcode}>>')

        # we have no JSON to return
        #
        return None

    # return SHA256 hash ASCII HEX digest string
    #
    hexdigest = h.hexdigest()
    debug(f'{me}: end: SHA256: {hexdigest}')
    return hexdigest


# pylint: disable=too-many-return-statements
# pylint: disable=too-many-branches
# pylint: disable=too-many-statements
#
def validate_slot_dict_nolock(slot_dict, username, slot_num):
    """
    Validate a slot's python dictionary.

    Given:
        slot_dict       slot JSON content as a python dictionary
        username        IOCCC submit server username
        slot_num        slot number for a given username

        NOTE: A JSON null, as Python dictionary, has the python value of None.

        NOTE: If filename is a string, then
                   length MUST be an int,
                   date MUST be a string,
                   SHA256 MUST be a string.
              Otherwise if filename is None (JSON null), then
                   length MUST be None (JSON null),
                   date MUST be None (JSON null),
                   SHA256 MUST be None (JSON null).

    Returns:
        None ==> no errors detected with the slot
        != None ==> slot error message string

    NOTE: This function performs various canonical firewall checks on the username arg.

    NOTE: This function performs various canonical firewall checks on the slot_num arg.

    WARNING: This function does NOT lock.  The caller should lock as needed.
    """

    # setup
    #
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - canonical firewall checks on the username arg
    #
    if not check_username_arg(username):

        # The check_username_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a username firewall check failure.
        #
        return 'invalid username arg'

    # firewall - canonical firewall checks on the slot_num arg
    #
    if not check_slot_num_arg(slot_num):

        # The check_slot_num_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a slot_num firewall check failure.
        #
        return 'invalid slot_num arg'

    # validate args
    #
    if not isinstance(slot_dict, dict):
        return 'slot_dict arg is not a python dictionary'

    # determine user directory path
    #
    user_dir = return_user_dir_path(username)
    if not user_dir:
        return 'invalid username arg'

    # determine slot directory path
    #
    slot_dir = return_slot_dir_path(username, slot_num)
    if not slot_dir:
        return 'invalid slot_num arg'

    # firewall check slot no_comment
    #
    if not 'no_comment' in slot_dict:
        return 'missing slot no_comment string'
    if not isinstance(slot_dict['no_comment'], str):
        return 'slot no_comment is not a string'
    if slot_dict['no_comment'] != NO_COMMENT_VALUE:
        return 'invalid slot no_comment'

    # firewall check slot_JSON_format_version
    #
    if not 'slot_JSON_format_version' in slot_dict:
        return 'missing slot_JSON_format_version string'
    if not isinstance(slot_dict['slot_JSON_format_version'], str):
        return 'slot_JSON_format_version is not a string'
    if slot_dict['slot_JSON_format_version'] != SLOT_VERSION_VALUE:
        return 'invalid slot_JSON_format_version'

    # slot must have the correct slot number
    #
    if not 'slot' in slot_dict:
        return 'missing slot number'
    if not isinstance(slot_dict['slot'], int):
        return 'slot number is not an int'
    if slot_dict['slot'] != slot_num:
        return 'wrong slot number'

    # if we have a filename, then the filename must be a valid filename string
    #
    submit_file = return_submit_filename(slot_dict, username, slot_num)
    filename_is_string = True
    if not submit_file:
        filename_is_string = False
    if filename_is_string:
        if not submit_file.startswith(f'submit.{username}-{slot_num}.'):
            return 'wrong slot filename beginning'
        if not submit_file.endswith('.txz'):
            return 'wrong slot filename extension'
        if not re.match(f'^submit\\.{username}-{slot_num}\\.[1-9][0-9]{{9,}}\\.txz$', submit_file):
            return 'invalid slot filename timestamp'

    # if we have a filename, then slot must have a valid slot length
    # otherwise we must not have a slot length
    #
    if not 'length' in slot_dict:
        return 'missing slot length int'
    if filename_is_string:
        if not isinstance(slot_dict['length'], int):
            return 'slot length is not an int'
        if slot_dict['length'] <= 0:
            return 'slot length not > 0'
    elif slot_dict['length']:
        return 'have length w/o filename'

    # if we have a filename, then slot must have a valid slot date
    # otherwise we must not have a slot date
    #
    if not 'date' in slot_dict:
        return 'missing slot date string'
    if filename_is_string:
        if not isinstance(slot_dict['date'], str):
            return 'slot date is not a string'
        try:
            # pylint: disable-next=unused-variable
            dt = datetime.strptime(slot_dict['date'], DATETIME_USEC_FORMAT)
        # pylint: disable-next=unused-variable
        except ValueError as errcode:
            return 'slot date format is invalid'
    elif slot_dict['date']:
        return 'have date w/o filename'

    # if we have a filename, then slot must have a valid SHA256 hash
    # otherwise we must not have a slot SHA256 hash
    #
    if not 'SHA256' in slot_dict:
        return 'missing slot SHA256 string'
    if filename_is_string:
        if not isinstance(slot_dict['SHA256'], str):
            return 'slot SHA256 is not a string'
        if len(slot_dict['SHA256']) != SHA256_HEXLEN:
            return 'slot SHA256 length is wrong'
    elif slot_dict['SHA256']:
        return 'have SHA256 w/o filename'

    # slot must have a collected boolean
    #
    if not 'collected' in slot_dict:
        return 'missing slot collected boolean'
    if not isinstance(slot_dict['collected'], bool):
        return 'slot collected is not a boolean'

    # slot must have a status string
    #
    if not 'status' in slot_dict:
        return 'missing slot status string'
    if not isinstance(slot_dict['status'], str):
        return 'slot status is not a string'

    # case: filename is a string
    #
    if filename_is_string:

        # determine full path of submit file
        #
        submit_path = f'{slot_dir}/{slot_dict["filename"]}'

        # case: submit file exists
        #
        if Path(submit_path).exists():

            # verify the submit file size
            #
            if os.path.getsize(submit_path) != slot_dict['length']:
                return 'submit file length is wrong'

    # case: filename is not a string, submit file is not required
    #
    elif slot_dict['collected']:
        return 'submit file was collected w/o filename'

    # no slot errors found
    #
    debug(f'{me}: end: no slot errors found for username: {username} slot_num: {slot_num}')
    return None
#
# pylint: enable=too-many-return-statements
# pylint: enable=too-many-branches
# pylint: enable=too-many-statements


# pylint: disable=too-many-return-statements
#
def get_slot_dict_nolock(username, slot_num):
    """
    read JSON data for a given slot

    Given:
        username    IOCCC submit server username
        slot_num    slot number for a given username

    Returns:
        None ==> invalid slot number or invalid user directory
        != None ==> slot information as a python dictionary

    NOTE: This function performs various canonical firewall checks on the username arg.

    NOTE: This function performs various canonical firewall checks on the slot_num arg.

    WARNING: This function does NOT lock.  The caller should lock as needed.
    """

    # setup
    #
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - canonical firewall checks on the username arg
    #
    if not check_username_arg(username):

        # The check_username_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a username firewall check failure.
        #
        return None

    # firewall - canonical firewall checks on the slot_num arg
    #
    if not check_slot_num_arg(slot_num):

        # The check_slot_num_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a slot_num firewall check failure.
        #
        return None

    # read the JSON file for the user's slot
    #
    slot_json_file = return_slot_json_filename(username, slot_num)
    if not slot_json_file:
        error(f'{me}: return_slot_json_filename failed for username: {username} slot_num: {slot_num}')
        return None
    slot_dict = read_json_file_nolock(slot_json_file)
    if not slot_dict:
        error(f'{me}: read_json_file_nolock failed for username: {username} slot_num: {slot_num} '
              f'slot_json_file: {slot_json_file}')
        return None

    # firewall - validate the slot python dictionary
    #
    err_msg = validate_slot_dict_nolock(slot_dict, username, slot_num)
    if err_msg:
        error(f'{me}: {err_msg} for: username: {username} slot_num: {slot_num} ')
        return None

    # return slot information as a python dictionary
    #
    debug(f'{me}: end: returning slot information')
    return slot_dict
#
# pylint: enable=too-many-return-statements


# pylint: disable=too-many-return-statements
# pylint: disable=too-many-branches
#
def validate_slot_nolock(slot_dict, username, slot_num, submit_required, check_hash):
    """
    Validate a slot.  After validating the function arguments,
    we verify that the username is a valid user in the password database.

    NOTE: This function does NOT attempt to determine if the username
          is allowed to login or perform certain actions: only that
          the username is a known username in the password database.

    After determining the path to the slot directory, and we obtain the
    slot python dictionary by reading the slot's JSON file.

    NOTE: No locks are obtained while reading the slot's JSON file.
          It is up to the caller to obtain any necessary locks.

    We then validate the slot python dictionary, checking the dictionary
    for the required values and their types.

    NOTE: This slot python dictionary will include checking if a referenced
          submit file, if it exists, has the proper length.

    If the slot python dictionary refers to a submit file:

        If the submit file exists, and we a checking the SHA256 hash, then
        we verify the contents of the submit file by checking the SHA256 hash.

        If the submit file not exist, we verify that a submit file is not required.

        If the submit file not exist, we verify it was not previously collected.

    If the slot python dictionary does not refer to a submit file:

        We verify that a submit file is not required.

        We verify that a previous submit file was not collected from this slot.

    Given:
        slot_dict       slot JSON content as a python dictionary
        username        IOCCC submit server username
        slot_num        slot number for a given username
        submit_required   True ==> submit file must exist
                          False ==> submit file may or may not exist
        check_hash      True ==> check the SHA256 hash of the submit file, if it exists
                        False ==> do not check the SHA256 hash

    Returns:
        None ==> no errors detected with the slot
        != None ==> slot error string

    NOTE: This function performs various canonical firewall checks on the username arg.

    NOTE: This function performs various canonical firewall checks on the slot_num arg.

    WARNING: This function does NOT lock.  The caller should lock as needed.
    """

    # setup
    #
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - canonical firewall checks on the username arg
    #
    if not check_username_arg(username):

        # The check_username_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a username firewall check failure.
        #
        return 'invalid username arg'

    # firewall - canonical firewall checks on the slot_num arg
    #
    if not check_slot_num_arg(slot_num):

        # The check_slot_num_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a slot_num firewall check failure.
        #
        return 'invalid slot_num arg'

    # validate boolean args
    #
    if not isinstance(slot_dict, dict):
        return 'slot_dict arg is not a python dictionary'
    if not isinstance(submit_required, bool):
        return 'submit_required arg is not a boolean'
    if not isinstance(check_hash, bool):
        return 'check_hash arg is not a boolean'

    # validate username
    #
    if not lookup_username(username):
        return 'lookup_username failed'

    # determine slot directory path
    #
    slot_dir = return_slot_dir_path(username, slot_num)
    if not slot_dir:
        return 'return_slot_dir_path failed'

    # validate JSON slot contents
    #
    slot_error = validate_slot_dict_nolock(slot_dict, username, slot_num)
    if not slot_error:
        return slot_error

    # determine full path of submit file
    #
    submit_path = return_submit_path(slot_dict, username, slot_num)

    # case: filename is a string
    #
    if submit_path:

        # case: submit file exists
        #
        if Path(submit_path).exists():

            # if check_hash, also check the SHA256 hash
            #
            if check_hash:

                # verify the SHA256 hash of the submit file
                #
                sha256 = sha256_file(submit_path)
                if not sha256:
                    return 'submit file SHA256 hash failed'

                # verify the content of the submit file
                #
                if sha256 != slot_dict['SHA256']:
                    return 'submit file corrupted contents'

            # verify that the submit file has not been collected
            #
            if slot_dict['collected']:
                return 'submit file collected but still exists'

        # case: submit file does not exist but is required to do so
        #
        elif submit_required:

            # if file is required, verify that submit file exists
            #
            return 'submit file is missing'

        # case: submit file does not exist and was never collected
        #
        elif not slot_dict['collected']:

            # submit file is gone but was never collected
            #
            return 'submit file is gone but not collected'

    # case: filename is not a string, but a submit file is required
    #
    elif submit_required:
        return 'submit file is expected to exist but does not'

    # case: filename is not a string, submit file is not required
    #
    elif slot_dict['collected']:
        return 'submit file was collected w/o filename'

    # no slot errors found
    #
    debug(f'{me}: end: no slot errors found')
    return None
#
# pylint: enable=too-many-return-statements
# pylint: enable=too-many-branches


# pylint: disable=too-many-return-statements
# pylint: disable=too-many-branches
#
def stage_submit(username, slot_num):
    """
    Move a submit file in a slot into either the good or bad staging area.
    Update the JSON slot file to both indicate that the submit file was
    collected AND to update the slot status comment.

    Given:
        username        IOCCC submit server username
        slot_num        slot number for a given username

    Returns:
        != None ==> SHA256 hash of file moved into the staging area
        None ==> unable to move submit file into staging area

    NOTE: This function performs various canonical firewall checks on the username arg.

    NOTE: This function performs various canonical firewall checks on the slot_num arg.
    """

    # setup
    #
    me = inspect.currentframe().f_code.co_name
    debug(f'{me}: start')

    # firewall - canonical firewall checks on the username arg
    #
    if not check_username_arg(username):

        # The check_username_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a username firewall check failure.
        #
        error(f'{me} invalid username arg')
        return None

    # firewall - canonical firewall checks on the slot_num arg
    #
    if not check_slot_num_arg(slot_num):

        # The check_slot_num_arg() function above will set ioccc_last_errmsg
        # and issue log messages due to a slot_num firewall check failure.
        #
        error(f'{me} invalid slot_num arg')
        return None

    # look up username to be sure it is in the password database
    #
    if not lookup_username(username):
        error(f'{me} unknown username: {username}')
        return None

    # Lock the slot
    #
    # This will create the lock file if needed.
    #
    slot_lock_fd = lock_slot(username, slot_num)
    if not slot_lock_fd:
        error(f'{me} lock_slot failed for username: {username} slot_num: {slot_num}')
        return None

    # determine slot directory path
    #
    slot_dir = return_slot_dir_path(username, slot_num)
    if not slot_dir:
        error(f'{me} return_slot_dir_path failed for username: {username} slot_num: {slot_num}')
        unlock_slot()
        return None

    # obtain path of the submit filename
    #
    slot_dict = get_slot_dict_nolock(username, slot_num)
    if not slot_dict:
        # caller will log the error
        unlock_slot()
        return None
    if not 'filename' in slot_dict or not slot_dict['filename']:
        error(f'submit filename is missing from slot for username: {username} slot_num: {slot_num}')
        unlock_slot()
        return None
    submit_path = f'{slot_dir}/{slot_dict["filename"]}'

    # validate the slot, submit file required, and check the SHA256 hash
    #
    slot_err = validate_slot_nolock(slot_dict, username, slot_num, True, True)
    if slot_err:

        # tell the user to try loading again
        #
        error(f'{me}: corrupted slot for for username: {username} slot_num: {slot_num} '
              f'slot error: {slot_err}')
        unlock_slot()
        return None

    # move the submit file to the good directory
    #
    try:
        os.replace(submit_path, f'{STAGED_DIR}/{slot_dict["filename"]}')
    except OSError as errcode:
        error(f'{me}: replace {submit_path} {STAGED_DIR}/{slot_dict["filename"]} for'
              f'username: {username} slot_num: {slot_num} failed: <<{errcode}>>')
        unlock_slot()
        return None

    # mark slot file as having been collected
    #
    slot_dict['collected'] = True
    slot_dict['status'] = 'successfully moved submit file into the staging area'

    # update the slot JSON file
    #
    slot_json_file = return_slot_json_filename(username, slot_num)
    if not slot_json_file:
        # caller will log the error
        unlock_slot()
        return None
    if not write_slot_json_nolock(slot_json_file, slot_dict):
        # caller will log the error
        unlock_slot()
        return None

    # all is well, return the SHA256 hash
    #
    # NOTE: The above call to validate_slot_nolock(), called validate_slot_dict_nolock()
    #       which in turn validated that we have a valid SHA256 hash string that matches
    #       the file that we just moved.
    #
    hexdigest = slot_dict['SHA256']
    debug(f'{me}: end: returning SHA256: {hexdigest} for username: {username} slot_num: {slot_num}')
    unlock_slot()
    return hexdigest
#
# pylint: enable=too-many-return-statements
# pylint: enable=too-many-branches
