# Klang Fork of Open Creator Rails

This is Klang's fork of [ChainSafe/open-creator-rails](https://github.com/ChainSafe/open-creator-rails).

## Git Remotes

| Remote | URL | Purpose |
|---|---|---|
| `upstream` | `https://github.com/ChainSafe/open-creator-rails.git` | ChainSafe's source repo |
| `klanggames` | `https://github.com/klanggames/open-creator-rails.git` | Klang's org fork |
| `origin` | your personal fork | For PRs to klanggames |

## What diverges from upstream

The only intentional divergence is **deployment config files** — these contain Seed-specific contract addresses and token addresses:

- `packages/config/src/deployments/registries_11155111.json` (Sepolia)
- `packages/config/src/deployments/registries_84532.json` (Base Sepolia)
- `packages/config/src/deployments/token_addresses.json`

Everything else should match upstream.

## Rules

1. **Don't modify upstream TypeScript files** unless absolutely necessary. ChainSafe actively changes `apps/indexer/`, `apps/contracts/`, and `packages/config/src/index.ts`. Modifying these creates merge conflicts.
2. **Deployment JSON conflicts are expected** when pulling upstream. Always resolve by keeping Seed's values.
3. **Seed-specific features** should live in clearly separated files/directories (not mixed into upstream files).

## Pulling upstream changes

```bash
git fetch upstream
git merge upstream/main
# Resolve any deployment JSON conflicts by keeping Seed's values
```
