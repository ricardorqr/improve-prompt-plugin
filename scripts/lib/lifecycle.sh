#!/usr/bin/env bash
#
# Reusable improve-prompt lifecycle helpers.
#
# Contract: the caller MUST export ROOT (repo root) before sourcing this file.
# Nothing here touches the real ~/.claude — run_lifecycle creates its own
# throwaway CLAUDE_CONFIG_DIR and trap-cleans it.
#
# Provides:
#   ok / bad                 — pass/fail reporters (increment $pass/$fail)
#   lifecycle_prev_tag VER   — newest git tag strictly older than vVER (or "")
#   run_lifecycle            — full six-step real-world flow; 0=pass 1=fail

# --- identity (pinned; the point of the test is to assert these) -------------
LC_PLUGIN="improve-prompt"
LC_MARKET="improve-prompt-marketplace"
LC_SPEC="$LC_PLUGIN@$LC_MARKET"
LC_SKILL="start"
LC_COMMAND="improve-prompt:start"

pass=0 fail=0
green="$(printf '\033[32m')"; red="$(printf '\033[31m')"; dim="$(printf '\033[2m')"; rst="$(printf '\033[0m')"
ok()  { pass=$((pass+1)); printf "  %sPASS%s %s\n" "$green" "$rst" "$1"; }
bad() { fail=$((fail+1)); printf "  %sFAIL%s %s\n" "$red" "$rst" "$1"; [ -n "${2:-}" ] && printf "       %s%s%s\n" "$dim" "$2" "$rst"; }

# Newest tag strictly older than vVER, by version sort. Empty if none.
lifecycle_prev_tag() { # <new_version>
  local newv="$1"
  git -C "$ROOT" tag -l 'v*' \
    | sort -V \
    | awk -v cur="v$newv" '{ if ($0 == cur) exit; print }' \
    | tail -1
}

# HEAD's version from the plugin manifest.
lifecycle_head_version() {
  python3 -c 'import json;print(json.load(open("'"$ROOT"'/plugins/improve-prompt/.claude-plugin/plugin.json"))["version"])'
}

# Record the on-disk install dir(s) for the plugin under a config dir.
_lc_installed_paths() { # <cfg>
  find "$1" -type d -path "*/$LC_PLUGIN/*" -prune -print 2>/dev/null | head -20
}

run_lifecycle() {
  local cfg newv oldtag details start_dir old_dir path
  cfg="$(mktemp -d)"
  # shellcheck disable=SC2317
  _lc_cleanup() { rm -rf "$cfg"; }
  trap _lc_cleanup RETURN

  local pcli
  pcli() { CLAUDE_CONFIG_DIR="$cfg" claude plugin "$@"; }

  newv="$(lifecycle_head_version)"
  oldtag="$(lifecycle_prev_tag "$newv")"

  printf "%sthrowaway config dir: %s%s\n" "$dim" "$cfg" "$rst"
  printf "%snew version: %s   old tag: %s%s\n\n" "$dim" "$newv" "${oldtag:-<none>}" "$rst"

  # === Phase OLD: install previous release, then uninstall and verify gone ===
  printf "Old version\n"
  local old_ref="$ROOT"
  if [ -n "$oldtag" ]; then
    # Materialize the old tag's tree in a temp checkout so the marketplace
    # source reflects the previous release, not HEAD.
    old_dir="$(mktemp -d)"
    if git -C "$ROOT" archive "$oldtag" | tar -x -C "$old_dir"; then
      old_ref="$old_dir"
      ok "materialized old release $oldtag"
    else
      bad "could not materialize $oldtag; using HEAD for old phase"
    fi
  else
    printf "  %s(no earlier tag than v%s — old phase uses HEAD)%s\n" "$dim" "$newv" "$rst"
  fi

  if pcli marketplace add "$old_ref" >/dev/null 2>&1 && pcli install "$LC_SPEC" >/dev/null 2>&1; then
    ok "installed old version from ${oldtag:-HEAD}"
  else
    bad "old install failed" "$(pcli install "$LC_SPEC" 2>&1 | tail -3)"
  fi
  old_paths="$(_lc_installed_paths "$cfg")"

  pcli uninstall "$LC_PLUGIN" >/dev/null 2>&1
  if pcli list 2>&1 | grep -qi "$LC_PLUGIN"; then
    bad "old version still listed after uninstall"
  else
    ok "old version deregistered (gone from \`plugin list\`)"
  fi
  local residue=0
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    [ -e "$path" ] && { residue=1; break; }
  done <<< "$old_paths"
  if [ "$residue" -eq 0 ]; then
    ok "all old-version files removed from disk"
  else
    bad "old-version files remain on disk" "$path"
  fi
  [ -n "${old_dir:-}" ] && rm -rf "$old_dir"

  # === Phase NEW: install HEAD, verify features, uninstall, verify gone =====
  printf "\nNew version\n"
  pcli marketplace add "$ROOT" >/dev/null 2>&1
  pcli marketplace update "$LC_MARKET" >/dev/null 2>&1
  if pcli install "$LC_SPEC" >/dev/null 2>&1; then
    ok "installed new version from HEAD"
  else
    bad "new install failed" "$(pcli install "$LC_SPEC" 2>&1 | tail -3)"
  fi

  details="$(pcli details "$LC_PLUGIN" 2>&1)"
  printf '%s' "$details" | grep -q "$newv" \
    && ok "installed version is $newv" \
    || bad "version $newv not in details" "$(printf '%s' "$details" | head -3)"

  start_dir="$(find "$cfg" -type d -path "*/$LC_PLUGIN/*/skills/$LC_SKILL" 2>/dev/null | head -1)"
  [ -n "$start_dir" ] \
    && ok "installed copy has skills/$LC_SKILL/" \
    || bad "installed copy missing skills/$LC_SKILL/"

  local stale
  stale="$(find "$cfg" -type d -path "*/$LC_PLUGIN/*/skills/improve-prompt" 2>/dev/null | head -1)"
  [ -z "$stale" ] \
    && ok "no stale skills/improve-prompt/ in installed copy" \
    || bad "stale skills/improve-prompt/ present" "$stale"

  # Derived command = <plugin name>:<skill dir name>, asserted against HEAD manifest.
  local pname sname derived
  pname="$(python3 -c 'import json;print(json.load(open("'"$ROOT"'/plugins/improve-prompt/.claude-plugin/plugin.json"))["name"])')"
  sname="$(basename "${start_dir:-$LC_SKILL}")"
  derived="$pname:$sname"
  [ "$derived" = "$LC_COMMAND" ] \
    && ok "derived command is /$LC_COMMAND" \
    || bad "derived command is /$derived, expected /$LC_COMMAND"

  new_paths="$(_lc_installed_paths "$cfg")"
  pcli uninstall "$LC_PLUGIN" >/dev/null 2>&1
  if pcli list 2>&1 | grep -qi "$LC_PLUGIN"; then
    bad "new version still listed after uninstall"
  else
    ok "new version deregistered (gone from \`plugin list\`)"
  fi
  residue=0
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    [ -e "$path" ] && { residue=1; break; }
  done <<< "$new_paths"
  if [ "$residue" -eq 0 ]; then
    ok "all new-version files removed from disk"
  else
    bad "new-version files remain on disk" "$path"
  fi

  printf "\n%d passed, %d failed\n" "$pass" "$fail"
  [ "$fail" -eq 0 ]
}
