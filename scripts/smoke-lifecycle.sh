#!/usr/bin/env bash
#
# Tier 2 — install → uninstall → reinstall lifecycle smoke test.
#
# Runs against a THROWAWAY config dir (CLAUDE_CONFIG_DIR in a mktemp dir) so it
# never touches your real ~/.claude. The marketplace is added from this local
# repo, so it tests the committed working tree (uncommitted changes are not
# seen — commit first if you want them covered).
#
# Because it shells out to the real `claude plugin` CLI and does git work, it's
# slower and network-touching; run it on demand, not in a pre-push hook.
#
# Verifies:
#   - install registers the plugin at the expected version
#   - uninstall deregisters it (gone from `plugin list`)
#   - reinstall brings back version 1.1.0 with skill `start`
#   - the old `improve-prompt` skill name is absent from the installed copy
#
# Exit 0 = pass, 1 = fail.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PLUGIN="improve-prompt"
MARKET="improve-prompt-marketplace"
SPEC="$PLUGIN@$MARKET"
EXPECT_SKILL="start"

# Expected version comes from the plugin manifest — no hardcoded drift.
EXPECT_VERSION="$(python3 -c 'import json;print(json.load(open("'"$ROOT"'/plugins/improve-prompt/.claude-plugin/plugin.json"))["version"])')"

pass=0 fail=0
green="$(printf '\033[32m')"; red="$(printf '\033[31m')"; dim="$(printf '\033[2m')"; rst="$(printf '\033[0m')"
ok()  { pass=$((pass+1)); printf "  %sPASS%s %s\n" "$green" "$rst" "$1"; }
bad() { fail=$((fail+1)); printf "  %sFAIL%s %s\n" "$red" "$rst" "$1"; [ -n "${2:-}" ] && printf "       %s%s%s\n" "$dim" "$2" "$rst"; }

CFG="$(mktemp -d)"
cleanup() { rm -rf "$CFG"; }
trap cleanup EXIT

# All CLI calls run against the isolated config dir.
pcli() { CLAUDE_CONFIG_DIR="$CFG" claude plugin "$@"; }

printf "improve-prompt · Tier 2 lifecycle smoke test\n"
printf "%sisolated config dir: %s%s\n" "$dim" "$CFG" "$rst"
printf "%sexpected version: %s%s\n\n" "$dim" "$EXPECT_VERSION" "$rst"

# --- Add marketplace from local repo + first install -------------------------
printf "Setup\n"
if pcli marketplace add "$ROOT" >/dev/null 2>&1; then
  ok "added marketplace from local repo"
else
  bad "could not add marketplace from $ROOT" "$(pcli marketplace add "$ROOT" 2>&1 | tail -3)"
  printf "\naborting — setup failed\n"; exit 1
fi
if pcli install "$SPEC" >/dev/null 2>&1; then
  ok "installed $SPEC"
else
  bad "install failed" "$(pcli install "$SPEC" 2>&1 | tail -3)"
  printf "\naborting — setup failed\n"; exit 1
fi

# --- Uninstall + verify removal ----------------------------------------------
printf "\nUninstall\n"
pcli uninstall "$PLUGIN" >/dev/null 2>&1
if pcli list 2>&1 | grep -qi "$PLUGIN"; then
  bad "plugin still listed after uninstall"
else
  ok "plugin gone from \`plugin list\`"
fi
if pcli details "$PLUGIN" >/dev/null 2>&1; then
  bad "\`plugin details\` still succeeds after uninstall"
else
  ok "\`plugin details\` reports not-installed"
fi

# --- Reinstall + verify version & skill --------------------------------------
printf "\nReinstall\n"
pcli marketplace update "$MARKET" >/dev/null 2>&1
if pcli install "$SPEC" >/dev/null 2>&1; then
  ok "reinstalled $SPEC"
else
  bad "reinstall failed" "$(pcli install "$SPEC" 2>&1 | tail -3)"
fi

details="$(pcli details "$PLUGIN" 2>&1)"
if printf '%s' "$details" | grep -q "$EXPECT_VERSION"; then
  ok "installed version is $EXPECT_VERSION"
else
  bad "version $EXPECT_VERSION not found in details" "$(printf '%s' "$details" | head -3)"
fi
if printf '%s' "$details" | grep -qiE "skills?.*\b$EXPECT_SKILL\b|\b$EXPECT_SKILL\b"; then
  ok "details lists skill '$EXPECT_SKILL'"
else
  bad "skill '$EXPECT_SKILL' not found in details" "$(printf '%s' "$details" | head -8)"
fi

# --- On-disk: renamed skill present, old name absent -------------------------
printf "\nInstalled files\n"
installed_start="$(find "$CFG" -type d -path "*/$PLUGIN/*/skills/$EXPECT_SKILL" 2>/dev/null | head -1)"
installed_old="$(find "$CFG" -type d -path "*/$PLUGIN/*/skills/improve-prompt" 2>/dev/null | head -1)"
if [ -n "$installed_start" ]; then
  ok "installed copy has skills/$EXPECT_SKILL/"
else
  bad "installed copy missing skills/$EXPECT_SKILL/"
fi
if [ -z "$installed_old" ]; then
  ok "installed copy has NO stale skills/improve-prompt/"
else
  bad "installed copy still has skills/improve-prompt/" "$installed_old"
fi

# --- Summary -----------------------------------------------------------------
printf "\n%d passed, %d failed\n" "$pass" "$fail"
printf "%s(throwaway config dir removed on exit; your real ~/.claude was untouched)%s\n" "$dim" "$rst"
[ "$fail" -eq 0 ] || exit 1
