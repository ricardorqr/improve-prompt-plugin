#!/usr/bin/env bash
#
# Tier 1 — static validation of the improve-prompt plugin.
#
# Runs entirely against the working tree. Touches NO global state
# (no ~/.claude, no installs). Safe for CI and pre-push hooks.
#
# Checks:
#   1. `claude plugin validate --strict` passes for both manifests.
#   2. Version agrees across plugin.json, CITATION.cff, and the top CHANGELOG entry.
#   3. The skill lives at skills/start/ with frontmatter `name: start`.
#   4. No stale skills/improve-prompt/ directory remains.
#   5. The derived slash command is `improve-prompt:start`.
#   6. The marketplace `source` path resolves to the plugin dir.
#
# Exit 0 = all pass, 1 = any failure.

set -uo pipefail

# Repo root = parent of this script's dir, regardless of CWD.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PLUGIN_DIR="plugins/improve-prompt"
PLUGIN_JSON="$PLUGIN_DIR/.claude-plugin/plugin.json"
MARKET_JSON=".claude-plugin/marketplace.json"

# Expected identity (the whole point of the test is to pin these).
EXPECT_PLUGIN="improve-prompt"
EXPECT_SKILL="start"
EXPECT_COMMAND="improve-prompt:start"

pass=0 fail=0 skip=0
green="$(printf '\033[32m')"; red="$(printf '\033[31m')"; yellow="$(printf '\033[33m')"; dim="$(printf '\033[2m')"; rst="$(printf '\033[0m')"

ok()   { pass=$((pass+1)); printf "  %sPASS%s %s\n" "$green" "$rst" "$1"; }
bad()  { fail=$((fail+1)); printf "  %sFAIL%s %s\n" "$red" "$rst" "$1"; [ -n "${2:-}" ] && printf "       %s%s%s\n" "$dim" "$2" "$rst"; }
skipped() { skip=$((skip+1)); printf "  %sSKIP%s %s\n" "$yellow" "$rst" "$1"; [ -n "${2:-}" ] && printf "       %s%s%s\n" "$dim" "$2" "$rst"; }

# Extract a JSON string field without requiring jq.
json_field() { # <file> <key>
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2],""))' "$1" "$2"
}

printf "improve-prompt · Tier 1 static validation\n\n"

# --- 1. Manifest validation (authoritative, --strict for CI-grade) -----------
# The `claude` CLI is optional: if it's not on PATH these two checks are SKIPPED
# (not failed), so the consistency checks below still gate everywhere. CI
# installs the CLI so the strict validation actually runs.
printf "Manifests\n"
if command -v claude >/dev/null 2>&1; then
  if claude plugin validate "$PLUGIN_DIR" --strict >/dev/null 2>&1; then
    ok "plugin manifest validates (--strict)"
  else
    bad "plugin manifest failed --strict" "$(claude plugin validate "$PLUGIN_DIR" --strict 2>&1 | tail -3)"
  fi
  if claude plugin validate . --strict >/dev/null 2>&1; then
    ok "marketplace manifest validates (--strict)"
  else
    bad "marketplace manifest failed --strict" "$(claude plugin validate . --strict 2>&1 | tail -3)"
  fi
else
  skipped "plugin manifest --strict validation" "claude CLI not on PATH"
  skipped "marketplace manifest --strict validation" "claude CLI not on PATH"
fi

# --- 2. Version agreement ----------------------------------------------------
printf "\nVersion consistency\n"
v_plugin="$(json_field "$PLUGIN_JSON" version)"
v_citation="$(grep -E '^version:' CITATION.cff | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
v_changelog="$(grep -E '^## \[[0-9]' CHANGELOG.md | head -1 | sed -E 's/^## \[([^]]+)\].*/\1/')"

printf "  %splugin.json=%s  CITATION.cff=%s  CHANGELOG=%s%s\n" "$dim" "$v_plugin" "$v_citation" "$v_changelog" "$rst"
if [ -n "$v_plugin" ] && [ "$v_plugin" = "$v_citation" ] && [ "$v_plugin" = "$v_changelog" ]; then
  ok "version matches across plugin.json, CITATION.cff, CHANGELOG ($v_plugin)"
else
  bad "version mismatch across files" "plugin.json=$v_plugin CITATION.cff=$v_citation CHANGELOG=$v_changelog"
fi

# --- 3 & 4. Skill layout -----------------------------------------------------
printf "\nSkill layout\n"
skill_md="$PLUGIN_DIR/skills/$EXPECT_SKILL/SKILL.md"
if [ -f "$skill_md" ]; then
  ok "skill file exists at skills/$EXPECT_SKILL/SKILL.md"
  skill_name="$(sed -n -E 's/^name:[[:space:]]*(.*)$/\1/p' "$skill_md" | head -1)"
  if [ "$skill_name" = "$EXPECT_SKILL" ]; then
    ok "SKILL.md frontmatter name is '$EXPECT_SKILL'"
  else
    bad "SKILL.md frontmatter name is '$skill_name', expected '$EXPECT_SKILL'"
  fi
else
  bad "missing skill file" "$skill_md not found"
fi

if [ -d "$PLUGIN_DIR/skills/improve-prompt" ]; then
  bad "stale skills/improve-prompt/ directory still present" "should have been renamed to skills/$EXPECT_SKILL/"
else
  ok "no stale skills/improve-prompt/ directory"
fi

# --- 5. Derived command ------------------------------------------------------
printf "\nDerived command\n"
plugin_name="$(json_field "$PLUGIN_JSON" name)"
derived="$plugin_name:$skill_name"
if [ "$derived" = "$EXPECT_COMMAND" ]; then
  ok "slash command derives to /$EXPECT_COMMAND"
else
  bad "slash command derives to /$derived, expected /$EXPECT_COMMAND"
fi
if [ "$plugin_name" = "$EXPECT_PLUGIN" ]; then
  ok "plugin.json name is '$EXPECT_PLUGIN'"
else
  bad "plugin.json name is '$plugin_name', expected '$EXPECT_PLUGIN'"
fi

# --- 6. Marketplace source resolves ------------------------------------------
printf "\nMarketplace wiring\n"
src="$(python3 -c 'import json; print(json.load(open(".claude-plugin/marketplace.json"))["plugins"][0]["source"])')"
if [ -d "$src" ] && [ -f "$src/.claude-plugin/plugin.json" ]; then
  ok "marketplace source '$src' resolves to a plugin"
else
  bad "marketplace source '$src' does not resolve to a plugin dir"
fi

# --- Summary -----------------------------------------------------------------
printf "\n%d passed, %d failed, %d skipped\n" "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ] || exit 1
