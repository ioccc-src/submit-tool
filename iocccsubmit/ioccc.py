#!/usr/bin/env python3
#
# pylint: disable=invalid-overridden-method
# pylint: disable=too-many-statements
#
"""
The IOCCC submit tool

This code is used to upload submissions to an open IOCCC (International
Obfuscated C Code Contest) to the submit.ioccc.org server.

This code is based on code originally written by Eliot Lear (@elear) in late 2021.
The [IOCCC judges](https://www.ioccc.org/judges.html) heavily modified
Eliot's code, so any fault you find should be blamed on them 😉 (that is, the
IOCCC Judges :-) ).

NOTE: This flask-login was loosly modeled after:

    https://github.com/costa-rica/webApp01-Flask-Login/tree/github-main
    https://nrodrig1.medium.com/flask-login-no-flask-sqlalchemy-d62310bb43e3
"""

# system imports
#
import sys
import inspect
import argparse
import os
import re
import logging


# 3rd party imports
#
from flask import Flask, render_template, request, redirect, url_for, flash
import flask_login
from flask_login import current_user


# import the ioccc python utility code
#
# Sort the import list with: sort -d -u
#
# pylint: disable-next=unused-import
from iocccsubmit.ioccc_common import \
    APPDIR, \
    MAX_PASSWORD_LENGTH, \
    MAX_TARBALL_LEN, \
    MIN_PASSWORD_LENGTH, \
    TCP_PORT, \
    change_startup_appdir, \
    contest_is_open, \
    dbg, \
    debug, \
    error, \
    get_all_json_slots, \
    info, \
    initialize_user_tree, \
    is_proper_password, \
    lookup_username, \
    must_change_password, \
    return_last_errmsg, \
    return_secret, \
    return_slot_dir_path, \
    return_user_dir_path, \
    setup_logger, \
    update_password, \
    update_slot, \
    user_allowed_to_login, \
    warn, \
    warning, \
    verify_hashed_password


# ioccc.py version
#
# NOTE: Use string of the form: "x.y[.z] YYYY-MM-DD"
#
VERSION = "2.1.1 2024-12-20"


# Configure the application
#
application = Flask(__name__,
            template_folder=APPDIR + '/templates',
            root_path=APPDIR)
application.config['MAX_CONTENT_LENGTH'] = MAX_TARBALL_LEN
application.config['FLASH_APP'] = "iocccsubmit"
#application.debug = True
application.debug = False
#application.config['FLASK_ENV'] = "development"
application.config['FLASK_ENV'] = "production"
#application.config['TEMPLATES_AUTO_RELOAD'] = True
application.config['TEMPLATES_AUTO_RELOAD'] = False
application.secret_key = return_secret()

# set application file paths
#
with application.test_request_context('/'):
    url_for('static', filename='style.css')
    url_for('static', filename='script.js')
    url_for('static', filename='ioccc.png')


# Setup the login manager
#
login_manager = flask_login.LoginManager()
login_manager.init_app(application)


# Trivial user class
#
class User(flask_login.UserMixin):
    """
    Trivial user class
    """
    user_dict = None
    id = None
    authenticated = False

    def __init__(self,username):
        self.user_dict = lookup_username(username)
        if self.user_dict:
            self.id = username

    def is_active(self):
        """True, as all users are active."""
        return True

    def get_id(self):
        """Return the username to satisfy Flask-Login's requirements."""
        return self.id

    def is_authenticated(self):
        """Return True if the user is authenticated."""
        return self.authenticated

    def is_anonymous(self):
        """False, as anonymous users aren't supported."""
        return False


@login_manager.user_loader
def user_loader(user_id):
    """
    load the user
    """
    user =  User(user_id)
    if user.id:
        return user
    return None


# pylint: disable=too-many-return-statements
#
@application.route('/', methods = ['GET', 'POST'])
def login():
    """
    Process login request
    """

    # setup
    #
    me = inspect.currentframe().f_code.co_name

    # case: process / POST
    #
    if request.method == 'POST':
        debug('{me}: start POST')
        form_dict = request.form.to_dict()
        username = form_dict.get('username')

        # case: If the user is valid known user
        #
        user = User(username)
        if not user.id:
            info(f'{me}: invalid username')
            flash("ERROR: invalid username and/or password")
            return render_template('login.html')

        # validate password
        #
        if verify_hashed_password(form_dict.get('password'),
                                  user.user_dict['pwhash']):

            # case: If the user is not allowed to login
            #
            if not user_allowed_to_login(user.user_dict):
                info(f'{me}: disabled: username: {username}')
                flash("ERROR: Sorry (tm Canada 🇨🇦) you cannot login at this time")
                return render_template('login.html')

            # case: username and password are good, complete the login
            #
            user.authenticated = True
            flask_login.login_user(user)
            info(f'{me}: success: username: {username}')

        # case: invalid password
        #
        else:
            info(f'{me}: invalid password: username: {username}')
            flash("ERROR: invalid username and/or password")
            return render_template('login.html')

        # get the JSON slots for the user and verify we have slots
        #
        slots = initialize_user_tree(username)
        if not slots:
            error(f'{me}: username: {username}: initialize_user_tree failed: <<{return_last_errmsg()}>>')
            flash("ERROR: in: " + me + ": initialize_user_tree failed: <<" + \
                  return_last_errmsg() + ">>")
            flask_login.logout_user()
            return render_template('login.html')

        # case: user is required to change password
        #
        if must_change_password(user.user_dict):
            info(f'{me}: required password change: username: {username}')
            flash("Notice: You are required to change your password")
            return redirect(url_for('passwd'))

        # render based on if the contest is open or not
        #
        close_datetime = contest_is_open()
        if close_datetime:

            # case: contest open - both login and user setup are successful
            #
            return render_template('submit.html',
                                   flask_login = flask_login,
                                   username = username,
                                   etable = slots,
                                   date=str(close_datetime).replace('+00:00', ''))

        # case: contest is not open - both login and user setup are successful
        #
        info('{me}: IOCCC is not open')
        flash("The IOCCC is not open")
        return render_template('not-open.html',
                               flask_login = flask_login,
                               username = username,
                               etable = slots)

    # case: process / GET
    #
    debug('{me}: start GET')
    return render_template('login.html')
#
# pylint: enable=too-many-return-statements


# pylint: disable=too-many-branches
# pylint: disable=too-many-return-statements
#
@application.route('/submit', methods = ['GET', 'POST'])
@flask_login.login_required
def submit():
    """
    Access the IOCCC Submission Page - Upload a file to a user's slot
    """

    # setup
    #
    me = inspect.currentframe().f_code.co_name

    # get username
    #
    debug(f'{me}: start')
    if not current_user.id:
        warning(f'{me}: login required')
        flash("ERROR: Login required")
        flask_login.logout_user()
        return redirect(url_for('login'))
    username = current_user.id
    # paranoia
    if not username:
        warning(f'{me}: invalid username')
        flash("ERROR: Login required")
        flask_login.logout_user()
        return redirect(url_for('login'))

    # setup for user
    #
    user_dir = return_user_dir_path(username)
    if not user_dir:
        error(f'{me}: username: {username}: initialize_user_tree failed: <<{return_last_errmsg()}>>')
        flash("ERROR: in: " + me + ": return_user_dir_path failed: <<" + \
              return_last_errmsg() + ">>")
        flask_login.logout_user()
        return redirect(url_for('login'))

    # get the JSON for all slots for the user
    #
    slots = get_all_json_slots(username)
    if not slots:
        error(f'{me}: username: {username}: get_all_json_slots failed: <<{return_last_errmsg()}>>')
        flash("ERROR: in: " + me + ": get_all_json_slots failed: <<" + \
              return_last_errmsg() + ">>")
        flask_login.logout_user()
        return redirect(url_for('login'))

    # case: user is required to change password
    #
    if must_change_password(current_user.user_dict):
        info(f'{me}: required password change: username: {username}')
        flash("User is required to change their password")
        return redirect(url_for('passwd'))

    # verify that the contest is still open
    #
    close_datetime = contest_is_open()
    if not close_datetime:
        info(f'{me}: IOCCC is not open')
        flash("The IOCCC is not open.")
        return render_template('not-open.html',
                               flask_login = flask_login,
                               username = username,
                               etable = slots)

    # verify they selected a slot number to upload
    #
    if not 'slot_num' in request.form:
        debug(f'{me}: No slot selected')
        flash("No slot selected")
        return render_template('submit.html',
                               flask_login = flask_login,
                               username = username,
                               etable = slots,
                               date=str(close_datetime).replace('+00:00', ''))
    user_input = request.form['slot_num']
    try:
        slot_num = int(user_input)
    except ValueError:
        debug(f'{me}: Slot number is not a number')
        flash("Slot number is not a number: " + user_input)
        return render_template('submit.html',
                               flask_login = flask_login,
                               username = username,
                               etable = slots,
                               date=str(close_datetime).replace('+00:00', ''))
    slot_num_str = user_input

    # verify slot number
    #
    slot_dir = return_slot_dir_path(username, slot_num)
    if not slot_dir:
        error(f'{me}: username: {username}: slot_num: {slot_num}: '
              f'return_slot_dir_path failed: <<{return_last_errmsg()}>>')
        flash("ERROR: in: " + me + ": return_slot_dir_path failed: <<" + \
              return_last_errmsg() + ">>")
        return render_template('submit.html',
                               flask_login = flask_login,
                               username = username,
                               etable = slots,
                               date=str(close_datetime).replace('+00:00', ''))

    # verify they selected a file to upload
    #
    if 'file' not in request.files:
        debug(f'{me}: No file part')
        flash('No file part')
        return render_template('submit.html',
                               flask_login = flask_login,
                               username = username,
                               etable = slots,
                               date=str(close_datetime).replace('+00:00', ''))
    file = request.files['file']
    if file.filename == '':
        debug(f'{me}: No selected file')
        flash('No selected file')
        return render_template('submit.html',
                               flask_login = flask_login,
                               username = username,
                               etable = slots,
                               date=str(close_datetime).replace('+00:00', ''))

    # verify that the filename is in a submit file form
    #
    re_match_str = "^submit\\." + username + "-" + slot_num_str + "\\.[1-9][0-9]{9,}\\.txz$"
    if not re.match(re_match_str, file.filename):
        debug(f'{me}: username: {username}: slot_num: {slot_num}: invalid form of a filename')
        flash("Filename for slot " + slot_num_str + " must match this regular expression: " + re_match_str)
        return render_template('submit.html',
                               flask_login = flask_login,
                               username = username,
                               etable = slots,
                               date=str(close_datetime).replace('+00:00', ''))

    # save the file in the slot
    #
    upload_file = user_dir + "/" + slot_num_str  + "/" + file.filename
    file.save(upload_file)
    if not update_slot(username, slot_num, upload_file):
        error(f'{me}: username: {username}: slot_num: {slot_num}: update_slot failed: <<{return_last_errmsg()}>>')
        flash("ERROR: in: " + me + ": update_slot failed: <<" + \
              return_last_errmsg() + ">>")
        return render_template('submit.html',
                               flask_login = flask_login,
                               username = username,
                               etable = slots,
                               date=str(close_datetime).replace('+00:00', ''))

    # report on the successful upload
    #
    info(f'{me}: username: {username}: slot_num: {slot_num}: uploaded: {file.filename}')
    flash("Uploaded file: " + file.filename)
    return render_template('submit.html',
                           flask_login = flask_login,
                           username = username,
                           etable = slots,
                           date=str(close_datetime).replace('+00:00', ''))
#
# pylint: enable=too-many-branches
# pylint: enable=too-many-return-statements


# pylint: disable=too-many-branches
# pylint: disable=too-many-return-statements
#
@application.route('/update', methods=["POST"])
@flask_login.login_required
def upload():
    """
    Upload slot file
    """

    # setup
    #
    me = inspect.currentframe().f_code.co_name

    # get username
    #
    debug(f'{me}: start')
    if not current_user.id:
        warning(f'{me}: login required')
        flash("ERROR: Login required")
        return redirect(url_for('login'))
    username = current_user.id
    # paranoia
    if not username:
        warning(f'{me}: invalid username')
        flash("ERROR: Login required")
        return redirect(url_for('login'))

    # get the JSON for all slots for the user
    #
    slots = get_all_json_slots(username)
    if not slots:
        error(f'{me}: username: {username}: get_all_json_slots failed: <<{return_last_errmsg()}>>')
        flash("ERROR: in: " + me + ": get_all_json_slots failed: <<" + \
              return_last_errmsg() + ">>")
        return redirect(url_for('login'))

    # setup for user
    #
    user_dir = return_user_dir_path(username)
    if not user_dir:
        error(f'{me}: username: {username}: return_user_dir_path failed: <<{return_last_errmsg()}>>')
        flash("ERROR: in: " + me + ": return_user_dir_path failed: <<" + \
              return_last_errmsg() + ">>")
        return redirect(url_for('login'))

    # case: user is required to change password
    #
    if must_change_password(current_user.user_dict):
        info(f'{me}: required password change: username: {username}')
        flash("User is required to change their password")
        return redirect(url_for('passwd'))

    # verify that the contest is still open
    #
    close_datetime = contest_is_open()
    if not close_datetime:
        info('{me}: IOCCC is not open')
        flash("The IOCCC is not open.")
        return render_template('not-open.html',
                               flask_login = flask_login,
                               username = username,
                               etable = slots)

    # verify they selected a slot number to upload
    #
    if not 'slot_num' in request.form:
        debug(f'{me}: No slot selected')
        flash("No slot selected")
        return render_template('submit.html',
                               flask_login = flask_login,
                               username = username,
                               etable = slots,
                               date=str(close_datetime).replace('+00:00', ''))
    user_input = request.form['slot_num']
    try:
        slot_num = int(user_input)
    except ValueError:
        debug(f'{me}: Slot number is not a number')
        flash("Slot number is not a number: " + user_input)
        return render_template('submit.html',
                               flask_login = flask_login,
                               username = username,
                               etable = slots,
                               date=str(close_datetime).replace('+00:00', ''))
    slot_num_str = user_input

    # verify slot number
    #
    slot_dir = return_slot_dir_path(username, slot_num)
    if not slot_dir:
        error(f'{me}: username: {username}: slot_num: {slot_num}: '
              f'return_slot_dir_path failed: <<{return_last_errmsg()}>>')
        flash("ERROR: in: " + me + ": return_slot_dir_path failed: <<" + \
              return_last_errmsg() + ">>")
        return render_template('submit.html',
                               flask_login = flask_login,
                               username = username,
                               etable = slots,
                               date=str(close_datetime).replace('+00:00', ''))

    # verify they selected a file to upload
    #
    if 'file' not in request.files:
        debug(f'{me}: No file part')
        flash('No file part')
        return render_template('submit.html',
                               flask_login = flask_login,
                               username = username,
                               etable = slots,
                               date=str(close_datetime).replace('+00:00', ''))
    file = request.files['file']
    if file.filename == '':
        debug(f'{me}: No selected file')
        flash('No selected file')
        return render_template('submit.html',
                               flask_login = flask_login,
                               username = username,
                               etable = slots,
                               date=str(close_datetime).replace('+00:00', ''))

    # verify that the filename is in a submit file form
    #
    re_match_str = "^submit\\." + username + "-" + slot_num_str + "\\.[1-9][0-9]{9,}\\.txz$"
    if not re.match(re_match_str, file.filename):
        debug(f'{me}: username: {username}: slot_num: {slot_num}: invalid form of a filename')
        flash("Filename for slot " + slot_num_str + " must match this regular expression: " + re_match_str)
        return render_template('submit.html',
                               flask_login = flask_login,
                               username = username,
                               etable = slots,
                               date=str(close_datetime).replace('+00:00', ''))

    # save the file in the slot
    #
    upload_file = user_dir + "/" + slot_num_str  + "/" + file.filename
    file.save(upload_file)
    if not update_slot(username, slot_num, upload_file):
        error(f'{me}: username: {username}: slot_num: {slot_num}: update_slot failed: <<{return_last_errmsg()}>>')
        flash("ERROR: in: " + me + ": update_slot failed: <<" + \
              return_last_errmsg() + ">>")
        return render_template('submit.html',
                               flask_login = flask_login,
                               username = username,
                               etable = slots,
                               date=str(close_datetime).replace('+00:00', ''))

    # report on the successful upload
    #
    info(f'{me}: username: {username}: slot_num: {slot_num}: uploaded: {file.filename}')
    flash("Uploaded file: " + file.filename)

    # both login and user setup are successful
    #
    return render_template('submit.html',
                           flask_login = flask_login,
                           username = username,
                           etable = get_all_json_slots(username),
                           date=str(close_datetime).replace('+00:00', ''))
#
# pylint: enable=too-many-branches
# pylint: enable=too-many-return-statements


@application.route('/logout')
def logout():
    """
    Logout.
    """

    # setup
    #
    me = inspect.currentframe().f_code.co_name

    debug(f'{me}: start')
    flask_login.logout_user()
    return redirect(url_for('login'))


# pylint: disable=too-many-branches
# pylint: disable=too-many-return-statements
# pylint: disable=too-many-statements
#
@application.route('/passwd', methods = ['GET', 'POST'])
def passwd():
    """
    Change user password
    """

    # setup
    #
    me = inspect.currentframe().f_code.co_name

    # get username
    #
    debug('passwd: start')
    if not current_user.id:
        warning("passwd: login required #0")
        flash("ERROR: Login required")
        return redirect(url_for('login'))
    username = current_user.id
    # paranoia
    if not username:
        warning("passwd: invalid username #0")
        flash("ERROR: Login required")
        return redirect(url_for('login'))

    # get the JSON for all slots for the user
    #
    slots = get_all_json_slots(username)
    if not slots:
        error(f'passwd: username: {username}: get_all_json_slots failed: <<{return_last_errmsg()}>>')
        flash("ERROR: in: " + me + ": get_all_json_slots failed: <<" + \
              return_last_errmsg() + ">>")
        return redirect(url_for('login'))

    # case: process passwd POST
    #
    if request.method == 'POST':
        debug('passwd: start POST')
        form_dict = request.form.to_dict()

        # If the user is allowed to login
        #
        user = User(username)
        if user.id:

            # get username
            #
            if not current_user.id:
                warning("passwd: login required #1")
                flash("ERROR: Login required")
                return redirect(url_for('login'))
            # paranoia
            if not username:
                warning("passwd: invalid username #1")
                flash("ERROR: Login required")
                return redirect(url_for('login'))

            # get form parameters
            #
            old_password = form_dict.get('old_password')
            if not old_password:
                debug(f'passwd: username: {username}: No current password')
                flash("ERROR: You must enter your current password")
                return redirect(url_for('login'))
            new_password = form_dict.get('new_password')
            if not new_password:
                debug(f'passwd: username: {username}: No new password')
                flash("ERROR: You must enter a new password")
                return redirect(url_for('login'))
            reenter_new_password = form_dict.get('reenter_new_password')
            if not reenter_new_password:
                debug(f'passwd: username: {username}: No reentered password')
                flash("ERROR: You must re-enter the new password")
                return redirect(url_for('login'))

            # verify new and reentered passwords match
            #
            if new_password != reenter_new_password:
                debug(f'passwd: username: {username}: new password not same as reentered password')
                flash("ERROR: New Password and Reentered Password are not the same")
                return redirect(url_for('passwd'))

            # disallow old and new passwords being substrings of each other
            #
            if new_password == old_password:
                debug(f'passwd: username: {username}: new password same as current password')
                flash("ERROR: New password cannot be the same as your current password")
                return redirect(url_for('passwd'))
            if new_password in old_password:
                debug(f'passwd: username: {username}: new password contains current password')
                flash("ERROR: New password must not contain your current password")
                return redirect(url_for('passwd'))
            if old_password in new_password:
                debug(f'passwd: username: {username}: current password contains new password')
                flash("ERROR: Your current password cannot contain your new password")
                return redirect(url_for('passwd'))

            # validate new password
            #
            if not is_proper_password(new_password):
                debug(f'passwd: username: {username}: new password rejected')
                flash("ERROR: New Password is not a valid password")
                flash(return_last_errmsg())
                return redirect(url_for('passwd'))

            # change user password
            #
            # NOTE: This will also validate the old password
            #
            if not update_password(username, old_password, new_password):
                error(f'passwd: username: {username}: failed to change password')
                flash("ERROR: Password not changed")
                flash(return_last_errmsg())
                return redirect(url_for('passwd'))

            # user password change successful
            #
            info(f'passwd: username: {username}: password changed')
            flash("Password successfully changed")
            return redirect(url_for('logout'))

    # case: process /passwd GET
    #
    debug('passwd: start GET')
    pw_change_by = current_user.user_dict['pw_change_by']
    return render_template('passwd.html',
                           flask_login = flask_login,
                           username = username,
                           pw_change_by = pw_change_by,
                           min_length = str(MIN_PASSWORD_LENGTH),
                           max_length = str(MAX_PASSWORD_LENGTH))
#
# pylint: enable=too-many-branches
# pylint: enable=too-many-return-statements
# pylint: enable=too-many-statements


# case: running from the command line
#
if __name__ == '__main__':

    # setup
    #
    program = os.path.basename(__file__)
    # pylint: disable-next=invalid-name
    logtype = "stdout"

    # parse args
    #
    parser = argparse.ArgumentParser(
                description="IOCCC submit server tool",
                epilog=f'{program} version: {VERSION}')
    parser.add_argument('-i', '--ip',
                        help="IP address to connect (def: 127.0.0.1)",
                        default="127.0.0.1",
                        action="store",
                        metavar='ip',
                        type=str)
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
    parser.add_argument('-p', '--port',
                        help="open port (def: 8191)",
                        default=8191,
                        action="store",
                        metavar='port',
                        type=int)
    parser.add_argument('-t', '--topdir',
                        help="application directory path: tree under appdir must be setup correctly",
                        metavar='appdir',
                        type=str)
    args = parser.parse_args()

    # setup logging according to -l logtype -L dbglvl
    #
    setup_logger(args.log, args.level)

    # disable werkzeug logging
    #
    werkzeug_log = logging.getLogger('werkzeug')

    # -t topdir - set the path to the top level application direcory
    #
    if args.topdir:
        if not change_startup_appdir(args.topdir):
            print("ERROR: change_startup_appdir error: <<" + return_last_errmsg() + ">>")
            sys.exit(3)

    # launch the application if run from the command line
    #
    application.run(host=args.ip, port=args.port, debug=True)

else:
    setup_logger("syslog", "info")
