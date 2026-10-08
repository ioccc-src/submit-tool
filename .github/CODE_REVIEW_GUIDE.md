# Copilot code review guide

Use this guide when reviewing changes to `ioccc-src/submit-tool`. The two
deployment targets are `conway.isthe.com` and `submit.ioccc.org`. Both currently
run RHEL 10.2; code must work on RHEL 10.2 or later and equivalent Linux
systems. The production hosts are restricted and are not available to Copilot
or GitHub Actions.

## Review priorities

Look for correctness, regressions, unsafe input or file handling, authentication
and authorization mistakes, accidental disclosure of credentials, unsafe
privilege changes, and changes that could alter IOCCC registration, submission,
or contest state. Check that shell code handles failures explicitly and remains
compatible with the Bash and system utilities available on the target Linux
systems. Existing shell scripts require Bash 5.1.8 or newer.

Review installation and ownership changes carefully. `make sbin_install` is
for Conway and other non-submit hosts; the Makefile explicitly forbids running
it on the submit server. `make root_install` is a privileged submit-server
deployment operation that changes `/var/ioccc`, ownership, permissions, and
SELinux file contexts. It must never be run against either production host as
part of a review or test.

Keep findings specific and actionable. Distinguish a confirmed defect from a
question or a suggestion, and do not report issues based only on hypothetical
behavior unsupported by the code.

## Required checks

Before installing a change, run the repository's build and validation steps
from the repository root:

```sh
make clobber all install
source venv/bin/activate
bin/pychk.sh
```

`bin/pychk.sh` must exit successfully. Every Python script must receive Pylint
10/10; when adding a Python script that is not already covered, add it to
`bin/pychk.sh`. The check also runs ShellCheck when the tool is present, so
install ShellCheck rather than accepting the script's no-ShellCheck notice.
Every `*.sh` file under `bin/` and `sbin/` must have a clean ShellCheck report:
no errors, warnings, or informational messages. `sbin/who_email.awk` is AWK and
is not included in that ShellCheck requirement.

Pull-request CI runs the build and `bin/pychk.sh`. Its separate Ubuntu
integration job runs `make root_install` only in a fresh, disposable GitHub
hosted runner, then checks the Apache-hosted login page and a generated
temporary account. It changes the initial password through the web application,
opens a disposable contest window, builds a pinned `mkiocccentry` revision,
and uses `test_ioccc/gen_submit.sh` to generate submission archives for that
account's UUID. It uploads the good slot-5 archive and verifies the stored
bytes, slot metadata, and the slot's displayed filename, length, and SHA256
against the original archive. The runner installs a C compiler/build tools and
`rsync` for the toolkit; account emails use random local parts at `example.org`.
This test does not validate the complete Pwned password dataset or archive
acceptance by the IOCCC judging process. That job checks out the private `lcn2/submit.httpd`
configuration using the `SUBMIT_HTTPD_READ_TOKEN` secret from the
`submit-httpd-e2e` Actions environment. Restrict that environment to deployments
from the `submit-workflow` branch and store the token only as an environment
secret, not a repository secret. The integration job runs only on pushes to or
manual dispatches from that trusted branch; it does not run on pull requests.
This prevents unreviewed PR code from receiving the private-repository token.
The job is not a test of SELinux enforcement on RHEL.

## Safe script testing

Do not execute scripts in `sbin/` by default. Conway's scheduled
`all-collect.sh` and `update_reg.sh` run as `chongo` only while the contest is
pending or open; their effects can impact registered or submitting users.
Other scripts may also change contest state. Never run an unlisted script as a
test, and never point a test at production files or services.

The following scripts may be checked manually with isolated local fixtures;
these checks are not required automated CI tests:

| Script | Safe test boundary |
| --- | --- |
| `sbin/comm_email.sh` | Use two temporary files containing one address per line; check that output contains addresses present only in the second file. |
| `sbin/filter.sh` | Use a temporary address-list file and verify the filtered output on stdout. |
| `sbin/jval.sh` | Use test JSON only; `jsp` must be installed with `pipx --global install jsp` and `~/.local/bin` on `PATH`. |
| `sbin/who_extract.sh` | Use a temporary working directory and fixture mail message. Verify any replacement of `freelists.lst` occurs only in that temporary directory; empty/no-address input must not alter it. |

Do not treat a passing manual check of these scripts as permission to run other
scripts or to use live IOCCC data.

## Installation and host checks

All host-specific checks below are performed by an authorized operator on an
isolated RHEL-compatible test system, not by Copilot and not on a production
host.

For Conway, validate `make sbin_install` as root on a disposable
RHEL-compatible system that satisfies the target's preconditions. The test
system must not have `/var/ioccc`, which the Makefile uses as a guard against
installing on the submit server. `sbin_install` installs scripts under
`/usr/local/sbin`; it does not authorize executing them.

For the submit-server installation, validate the root-only installation path
on an isolated system with SELinux support and the expected `apache` user and
group. The operator's production sequence is:

```sh
make clobber all install
source venv/bin/activate
bin/pychk.sh
```

Then, as root from the repository root:

```sh
make root_install
```

The root install and a login test must use only disposable test data on the
isolated system. A separate operator-run check on a SELinux-enforcing system is
required to validate enforcement; the hosted Ubuntu integration job does not
claim to provide that.

GitHub Actions must not deploy to Conway or `submit.ioccc.org`. It may run the
root-only `root_install` target only inside its fresh hosted VM. The
`submit.httpd` configuration and generated credentials used by that test are
test-only; no production account, password, or data may be used.

The private configuration checkout token must be an environment secret on the
`submit-httpd-e2e` environment. Configure that environment's deployment
branches to allow only `submit-workflow`. Do not store this token as a
repository-level secret; the integration test deliberately does not run for
pull requests.
