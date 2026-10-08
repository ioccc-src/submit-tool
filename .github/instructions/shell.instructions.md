---
applyTo: "bin/**/*.sh,sbin/**/*.sh"
---

For shell changes, preserve compatibility with RHEL 10.2 or later and the
repository's Bash 5.1.8 minimum. Quote expansions, check command failures, and
preserve the scripts' established exit-code and diagnostic conventions.

Every shell script under `bin/` and `sbin/` must pass ShellCheck with no errors,
warnings, or informational messages. Do not execute operational scripts as
tests unless the code review guide explicitly lists them as safe and the test
uses isolated fixtures. Never connect to or operate on either production host.
