---
applyTo: "iocccsubmit/**/*.py,bin/**/*.py"
---

Keep Python code compatible with the supported RHEL 10.2+ runtime and existing
project dependencies. Follow the repository's error-reporting and logging
patterns. Python scripts checked by `bin/pychk.sh` must retain a Pylint score of
10/10; update that check when adding a Python script that must be covered.

Do not use real IOCCC accounts, production paths, or production services in
tests.
