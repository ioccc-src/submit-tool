#!/usr/bin/env python3
#
# __init__.py - IOCCC submit tool module __init__

"""
__init__.py - IOCCC submit tool module __init__
"""


# import ioccc_common functions
#
# Sort the import list with: sort -d -u
#
from .ioccc_common import \
        APPDIR, \
        DEFAULT_GRACE_PERIOD, \
        MAX_PASSWORD_LENGTH, \
        MAX_SUBMIT_SLOT, \
        MAX_TARBALL_LEN, \
        MIN_PASSWORD_LENGTH, \
        TCP_PORT, \
        cd_appdir, \
        change_startup_appdir, \
        check_slot_num_arg, \
        check_username_arg, \
        contest_is_open, \
        debug, \
        delete_username, \
        error, \
        generate_password, \
        get_all_json_slots, \
        hash_password, \
        info, \
        initialize_user_tree, \
        is_proper_password, \
        lookup_username, \
        must_change_password, \
        prerr, \
        read_state, \
        return_client_ip, \
        return_last_errmsg, \
        return_secret, \
        return_slot_dir_path, \
        return_slot_json_filename, \
        return_user_dir_path, \
        setup_logger, \
        stage_submit, \
        update_password, \
        update_slot, \
        update_slot_status, \
        update_slot_status_if_submit, \
        update_state, \
        update_username, \
        user_allowed_to_login, \
        warning


# final imports
#
from .ioccc import application
