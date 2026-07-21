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
LC_SKILLS=(start coding writing analysis)

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

# Assert every recorded version dir is "removed" after uninstall. On CLI 2.1.x
# `claude plugin uninstall` deregisters the plugin and marks its cache dir
# .orphaned_at for deferred GC rather than deleting it (and no purge command
# exists), so "removed" means absent OR carrying an .orphaned_at tombstone —
# not physically gone.
_lc_assert_tombstoned() { # <label> <newline-separated paths>
  local label="$1" paths="$2" live="" path
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    if [ -e "$path" ] && [ ! -f "$path/.orphaned_at" ]; then
      live="$path"; break
    fi
  done <<< "$paths"
  if [ -z "$live" ]; then
    ok "$label removed or tombstoned (.orphaned_at) after uninstall"
  else
    bad "$label still live on disk (no .orphaned_at)" "$live"
  fi
}

run_lifecycle() {
  local cfg newv oldtag details old_dir newdir
  cfg="$(mktemp -d)"
  # shellcheck disable=SC2317
  _lc_cleanup() { rm -rf "$cfg"; }
  trap _lc_cleanup RETURN

  # bash has no function-local functions; single-caller/single-shot use makes
  # pcli's global namespace immaterial here.
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
  local old_paths
  old_paths="$(_lc_installed_paths "$cfg")"

  pcli uninstall "$LC_PLUGIN" >/dev/null 2>&1
  if pcli list 2>&1 | grep -qi "$LC_PLUGIN"; then
    bad "old version still listed after uninstall"
  else
    ok "old version deregistered (gone from \`plugin list\`)"
  fi
  _lc_assert_tombstoned "old-version files" "$old_paths"
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

  # Feature checks are scoped to the LIVE installed version dir, not the whole
  # config dir — tombstoned (.orphaned_at) dirs left by the old phase must not
  # leak into the new-version assertions.
  newdir="$cfg/plugins/cache/$LC_MARKET/$LC_PLUGIN/$newv"
  local skill
  for skill in "${LC_SKILLS[@]}"; do
    [ -d "$newdir/skills/$skill" ] \
      && ok "installed copy has skills/$skill/" \
      || bad "installed copy missing skills/$skill/" "$newdir"
  done

  if [ -d "$newdir/skills/improve-prompt" ]; then
    bad "stale skills/improve-prompt/ present" "$newdir/skills/improve-prompt"
  else
    ok "no stale skills/improve-prompt/ in installed copy"
  fi

  # The installed copy's skill dirs must be EXACTLY the expected set — no
  # extra, none missing. (Avoids relying on filesystem enumeration order,
  # which broke the old single-skill "pick the first one" assumption.)
  local actual_sorted expected_sorted
  actual_sorted="$(find "$newdir/skills" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort)"
  expected_sorted="$(printf '%s\n' "${LC_SKILLS[@]}" | sort)"
  [ "$actual_sorted" = "$expected_sorted" ] \
    && ok "installed copy's skill dirs match expected set (${LC_SKILLS[*]})" \
    || bad "installed copy's skill dirs mismatch" "expected: $(printf '%s ' $expected_sorted) / actual: $(printf '%s ' $actual_sorted)"

  pcli uninstall "$LC_PLUGIN" >/dev/null 2>&1
  if pcli list 2>&1 | grep -qi "$LC_PLUGIN"; then
    bad "new version still listed after uninstall"
  else
    ok "new version deregistered (gone from \`plugin list\`)"
  fi
  _lc_assert_tombstoned "new-version files" "$newdir"

  printf "\n%d passed, %d failed\n" "$pass" "$fail"
  [ "$fail" -eq 0 ]
}
