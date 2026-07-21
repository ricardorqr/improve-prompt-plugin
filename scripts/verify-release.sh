#!/usr/bin/env bash
#
# Local, wait-for-green release verification.
#
# 1. Waits for the CI run of the current HEAD commit on the remote to conclude.
# 2. Aborts unless that run succeeded.
# 3. Runs the shared six-step lifecycle (scripts/lib/lifecycle.sh) against a
#    throwaway config dir — the real ~/.claude is never touched.
#
# Requires: gh (authed), claude CLI, network. Run AFTER pushing.
# Exit 0 = CI green AND lifecycle passed.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT
# shellcheck source=lib/lifecycle.sh
source "$ROOT/scripts/lib/lifecycle.sh"

dim="$(printf '\033[2m')"; red="$(printf '\033[31m')"; rst="$(printf '\033[0m')"
die() { printf "%sverify-release: %s%s\n" "$red" "$1" "$rst" >&2; exit 1; }

command -v gh >/dev/null 2>&1 || die "gh CLI not found on PATH"

sha="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null)" \
  || die "not a git repo (or no HEAD) at $ROOT"
[ -n "$sha" ] || die "could not resolve HEAD commit"
printf "verify-release · waiting for CI on %s%s%s\n" "$dim" "${sha:0:12}" "$rst"

# Find the most recent run for this commit. Retry briefly — the run may not be
# registered the instant after a push. `// empty` turns an empty result into an
# empty string (jq renders a missing field as the literal "null" otherwise,
# which would break the retry). A genuine gh failure (auth/network/wrong
# remote) fails the command, so we abort immediately instead of mistaking it
# for "no run yet".
run_id=""
for _ in 1 2 3 4 5 6; do
  if ! run_id="$(gh run list --commit "$sha" --limit 1 --json databaseId \
                   --jq '.[0].databaseId // empty')"; then
    die "gh run list failed for $sha (auth, network, or wrong remote?)"
  fi
  [ -n "$run_id" ] && break
  printf "  %sno run registered yet for this commit; retrying in 10s…%s\n" "$dim" "$rst"
  sleep 10
done
[ -n "$run_id" ] || die "no CI run found for $sha after retrying (did you push this commit?)"

printf "  watching run %s… (live progress below)\n" "$run_id"
# --exit-status makes gh return non-zero if the run concluded in failure.
# Output is left visible so the user sees progress during the (minutes-long) wait.
if ! gh run watch "$run_id" --exit-status; then
  die "CI run $run_id did not succeed — not running lifecycle"
fi
printf "  CI is green ✓\n\n"

printf "improve-prompt · lifecycle (post-green)\n"
run_lifecycle
