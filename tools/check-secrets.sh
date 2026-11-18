#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
SCANNER=${GITLEAKS:-gitleaks}
if ! command -v "$SCANNER" >/dev/null 2>&1; then
    echo 'Install Gitleaks 8.30.1 or set GITLEAKS to its executable path.' >&2
    exit 1
fi
# Do not print actual credential values if a finding blocks the check.
"$SCANNER" git --no-banner --redact --log-opts=--all .
"$SCANNER" git --no-banner --redact --pre-commit --staged .
"$SCANNER" git --no-banner --redact --pre-commit .
