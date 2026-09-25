#!/bin/sh
CIRCLECI_TOKEN="$(security find-generic-password -s "${CLAUDE_CCI_KEYCHAIN_ITEM:-circleci-token}" -w)"
export CIRCLECI_TOKEN
exec npx -y @circleci/mcp-server-circleci
