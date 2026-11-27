# dotfiles

hikae's development environment, declared so that any machine can be rebuilt from this repository alone.

## Intent

- **Reproducible.** Every package, setting, and background service is declared in a Nix flake. A new or wiped machine reaches the same state from one command; nothing is configured by hand.
- **Verifiable supply chain.** Software comes only from binary caches, checksummed releases, or signed upstream installers. Nothing is built from source locally, so what runs is what was reviewed.
- **Least privilege by trust tier.** Machines, humans, AI agents, and AWS accounts each get only the access their role needs. A machine assumed compromised can never write to a trusted one. See the [threat model](docs/security/threat-model.md) and [policy diagram](docs/security/policy.png).
- **No standing secrets.** Credentials are short-lived and brokered; secrets are encrypted at rest and handed only to the repository that needs them.
- **Self-maintaining.** Inputs update weekly behind a CI gate, machines pull `main` daily, and audits report drift instead of letting it accumulate.
- **Safe for agents.** AI agents work inside sandboxes with shared, centrally managed instructions, and can carry changes through to release without holding long-lived credentials.

## Machines

| Machine     | Role                                                   |
| ----------- | ------------------------------------------------------ |
| macbook-air | Thin client; the entry point a human operates          |
| mac-studio  | Development machine that holds credentials             |
| ms-a2       | Credential-free machine for AI agents, CI, experiments |

## Where to go next

- [AGENTS.md](AGENTS.md) — where each kind of change belongs and repository conventions
- [docs/playbooks.md](docs/playbooks.md) — index of operational procedures
- [docs/operations.md](docs/operations.md) — install, daily operation, troubleshooting, recovery
- [docs/security/](docs/security/) — trust tiers and threat model
