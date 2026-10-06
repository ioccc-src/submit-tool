# Copilot instructions

For code reviews, follow [CODE_REVIEW_GUIDE.md](CODE_REVIEW_GUIDE.md). Review the
changed code in its repository context and report only actionable findings, with
file and line references.

The production hosts `conway.isthe.com` and `submit.ioccc.org` are restricted.
Do not attempt to connect to them or imply that they were tested. Never run
deployment commands against either host. `submit.ioccc.org` is user-facing:
tests must not run scripts that collect, register, create, or alter real IOCCC
user or contest data.

The GitHub Actions end-to-end job runs only in its disposable hosted runner.
Never move production credentials or data into that job. Shell scripts under
`bin/` and `sbin/` must pass ShellCheck without any diagnostic; `sbin/who_email.awk`
is AWK, not a shell script.
