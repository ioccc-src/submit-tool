#!/usr/bin/env python3
#
# ioccc.wsgi - IOCCC submit tool server
#
# pylint: disable=unused-import

"""
ioccc.wsgi - IOCCC submit tool server application

This code is executed by the Apache wsgi module via configuration
in the /etc/httpd/conf/wsgi.conf file on the submit server.
"""


import sys
import site

# Ensure system-installed local site-packages (from make root_install) are accessible
#
site.addsitedir("/usr/local/lib/python" + sys.version[:4] + "/site-packages")
site.addsitedir("/usr/local/lib64/python" + sys.version[:4] + "/site-packages")


# import the ioccc server and common utility code
#
# pylint: disable=wrong-import-position
from iocccsubmit import application, setup_logger


# ioccc.wsgi version
#
# NOTE: Use string of the form: "x.y[.z] YYYY-MM-DD"
#
VERSION_IOCCC_WSGI = "2.2.1 2026-08-19"


# setup logging as syslog at INFO level
#
setup_logger("syslog", "info")


# application = create_app(__name__)
