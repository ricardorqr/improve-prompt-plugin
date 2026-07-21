# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-07-21

### Added
- `/improve-prompt:coding`, `/improve-prompt:writing`, and
  `/improve-prompt:analysis` commands. Each hard-locks its variant — no
  inference, no fallback to General — for when you already know which lens
  you want. `start` is unchanged and continues to auto-detect/hint across
  all four variants.

## [1.1.2] - 2026-07-21

### Changed
- The `start` skill now requires explicit `##` headings for every section of
  its output (`Ambiguities & Assumptions`, `Approach`, `Variant A`, `Variant B`,
  `Recommendation`) instead of a plain numbered list, so the reader can see
  where each part starts and ends.

## [1.1.1] - 2026-07-20

### Added
- GitHub Actions release automation: on a version bump landing on `master`
  (after the Tier 1 + Tier 2 test jobs pass), CI cuts the matching `vX.Y.Z` tag
  and GitHub Release from the changelog, and best-effort syncs the repo About
  description and topics from `.github/repo-metadata.json`.
- `scripts/verify-release.sh` — waits for the pushed commit's CI run to go green,
  then runs a six-step install/uninstall lifecycle test against a throwaway
  config dir (shared with the CI Tier 2 job via `scripts/lib/lifecycle.sh`).

## [1.1.0] - 2026-07-20

### Changed
- Renamed the skill from `improve-prompt` to `start`, so the command now reads
  `/improve-prompt:start` instead of the doubled-up `/improve-prompt:improve-prompt`.

## [1.0.2] - 2026-07-20

### Changed
- Generalized the model reference from "Claude Opus 4.8" to "Claude" across the
  skill, manifests, and README so the copy no longer goes stale on model
  releases.

### Added
- `license` field (`MIT`) in `plugin.json` to match the repository license.

### Fixed
- Aligned `date-released` in `CITATION.cff` with the changelog.

## [1.0.1] - 2026-07-15

### Added
- `displayName`, `author`, `homepage`, and `repository` fields in `plugin.json`
  so the plugin surfaces attribution and repository details in the marketplace.

## [1.0.0] - 2026-07-15

### Added
- Initial release of the **improve-prompt** plugin.
- `improve-prompt` skill and `/improve-prompt` command that rewrite a draft
  prompt into two improved variants plus a recommendation, tuned for coding,
  writing, analysis, or general tasks.
- Marketplace manifest so the plugin is installable via Claude Code.

[1.2.0]: https://github.com/ricardorqr/improve-prompt-plugin/releases/tag/v1.2.0
[1.1.1]: https://github.com/ricardorqr/improve-prompt-plugin/releases/tag/v1.1.1
[1.1.0]: https://github.com/ricardorqr/improve-prompt-plugin/releases/tag/v1.1.0
[1.0.2]: https://github.com/ricardorqr/improve-prompt-plugin/releases/tag/v1.0.2
[1.0.1]: https://github.com/ricardorqr/improve-prompt-plugin/releases/tag/v1.0.1
[1.0.0]: https://github.com/ricardorqr/improve-prompt-plugin/releases/tag/v1.0.0
