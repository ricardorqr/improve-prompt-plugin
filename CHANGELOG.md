# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.1.0]: https://github.com/ricardorqr/improve-prompt-plugin/releases/tag/v1.1.0
[1.0.2]: https://github.com/ricardorqr/improve-prompt-plugin/releases/tag/v1.0.2
[1.0.1]: https://github.com/ricardorqr/improve-prompt-plugin/releases/tag/v1.0.1
[1.0.0]: https://github.com/ricardorqr/improve-prompt-plugin/releases/tag/v1.0.0
