# improve-prompt — Claude Code Plugin

A Claude Code plugin that rewrites your draft prompts into stronger ones for
Claude Opus 4.8. Given any prompt, it flags what's missing, then returns **two
improved variants plus a recommendation**, tuned for one of four task types:
General, Coding, Writing, or Analysis.

Once installed it works two ways:
- As the **`/improve-prompt`** slash command, and
- As an **auto-triggering skill** (just paste a draft and ask to improve it).

---

## Install (for teammates)

Add the marketplace once, then install the plugin:

```
/plugin marketplace add ricardorqr/improve-prompt-plugin
/plugin install improve-prompt@improve-prompt-marketplace
```

Restart Claude Code (or start a new session) and confirm a single
`/improve-prompt` entry appears in the `/` menu.

## Update

```
/plugin marketplace update improve-prompt-marketplace
/plugin install improve-prompt@improve-prompt-marketplace
```

## Uninstall

Uninstalling removes the **entire plugin** — the skill and the
`/improve-prompt` command — in one atomic action. Nothing is left behind.

```
/plugin uninstall improve-prompt@improve-prompt-marketplace
```

- **Disable instead of remove:** use the `/plugin` menu to toggle it off while
  keeping it installed.
- **Removing the marketplace** (`/plugin marketplace remove improve-prompt-marketplace`)
  only stops future installs/updates from this source; it does not uninstall an
  already-installed plugin.

---

## Using it

- **With your draft inline:** `/improve-prompt fix my flaky pytest suite`
- **Command alone:** type `/improve-prompt`, then paste your draft next.
- **No command at all:** paste a draft and say *"make this prompt better"* — the
  skill auto-triggers.

Hint the variant explicitly if you want: `/improve-prompt coding ...`,
`/improve-prompt writing ...`, `/improve-prompt analysis ...`, or
`/improve-prompt general ...`. Otherwise it infers the best fit (defaulting to
General).

### What you get back

1. A short list of ambiguities/missing info + any assumptions made
2. A one-line explanation of the approach
3. **Two rewritten prompts** in separate code blocks — (a) tightest rewrite, (b) a different angle
4. A recommendation on which to use and why

---

## Repo layout

```
improve-prompt-plugin/
├── .claude-plugin/
│   └── marketplace.json                 # marketplace manifest (lists the plugin)
└── plugins/
    └── improve-prompt/
        ├── .claude-plugin/
        │   └── plugin.json              # plugin manifest (name, version, keywords)
        └── skills/
            └── improve-prompt/
                └── SKILL.md             # the skill (command + auto-trigger)
```

## Maintaining

- Edit the skill at `plugins/improve-prompt/skills/improve-prompt/SKILL.md`.
- Bump `version` in `plugins/improve-prompt/.claude-plugin/plugin.json` on each
  change so teammates can pull updates.
- Push to GitHub. Teammates run the **Update** commands above.
