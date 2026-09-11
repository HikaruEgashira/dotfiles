# ponytail (open code data-only install)

Vendored from https://github.com/DietrichGebert/ponytail (MIT, v4.9.0, commit 0a4dd63).
The shipped OpenCode plugin (`@dietrichgebert/ponytail`) uses the V1 plugin API and does not
execute in OpenCode V2 ("V1 plugins will not work in V2"), so only the agent data is installed:

- `AGENTS.md` — always-on ruleset (concatenated with the shared system prompt by `modules/programs/opencode.nix` into `~/.config/opencode/AGENTS.md`)
- `commands/` — slash-command templates (linked as `~/.config/opencode/commands`)
- `skills/` — six skills registered via the `skills` array in `~/.config/opencode/opencode.json`

Switching ponytail levels (`/ponytail lite|full|ultra|off`) needs the plugin; it is not available
here. Switch to the official npm package once the upstream V2 adapter (PR #729/#734) merges.

Update: fetch upstream and re-copy these three pieces from the checkout root and `.opencode/command/`.
