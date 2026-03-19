#!/bin/bash
set -euo pipefail

# Only run in remote (Claude Code on the web) environments
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# No dependency manifests found in this repository.
# Add dependency installation commands here as the project grows.
# Examples:
#   npm install
#   pip install -r requirements.txt
#   bundle install

echo "Session start hook completed successfully."
