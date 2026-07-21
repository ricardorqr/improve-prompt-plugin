#!/usr/bin/env bash
#
# Tier 2 — real-world uninstall/install lifecycle smoke test.
#
# Runs against a THROWAWAY config dir so it never touches your real ~/.claude.
# Delegates to scripts/lib/lifecycle.sh (shared with scripts/verify-release.sh).
# Tests the committed working tree — commit local changes first to cover them.
#
# Exit 0 = pass, 1 = fail.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT
# shellcheck source=lib/lifecycle.sh
source "$ROOT/scripts/lib/lifecycle.sh"

printf "improve-prompt · Tier 2 lifecycle smoke test\n"
run_lifecycle
