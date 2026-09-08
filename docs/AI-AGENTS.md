# HWControl Custom Agents

This repository uses specialized GitHub Copilot custom agents so recurring engineering work is isolated by responsibility instead of relying on one unrestricted agent prompt.

## Agent map

| Agent | Primary responsibility | Typical trigger | Changes code? |
|---|---|---|---|
| CI Debugger | GitHub Actions failures and test/build regressions | Failed CI run | Yes, through a focused branch/PR |
| Branch Manager | Branch inventory, divergence, stale/duplicate branch cleanup | Branch hygiene task | Only when needed for safe maintenance |
| Security Reviewer | Security boundaries, supply chain, secrets, signing, privileged paths | Security review or suspected vulnerability | Yes, when remediation is clear |
| Release Engineer | Release packaging, checksums, signatures, attestations, publication readiness | Release preparation/failure | Yes, through a focused branch/PR |
| Installer Engineer | MSI/Setup/PKG/DMG/DEB/archive packaging and smoke tests | Installer/package failure | Yes, through a focused branch/PR |
| Website Release | GitHub Release to Pages/download synchronization | Web/release asset mismatch | Yes, through a focused branch/PR |
| Maintenance Agent | Dependency, Actions, docs, and technical-debt maintenance | Routine maintenance | Yes, through a focused branch/PR |

## Change-control model

`main` remains the protected integration branch. Agents should inspect first, make the smallest justified change, validate it, and use a focused branch and pull request for code changes.

Agents must not expose or modify secret values, private signing keys, certificate passwords, or credentials. Agents must not weaken authentication, checksums, signatures, attestations, security checks, or smoke tests merely to make automation pass.

## Recommended workflow

```text
Issue / failed workflow / release problem
                |
                v
        Select specialist agent
                |
                v
       Inspect actual evidence
                |
                v
       Reproduce / isolate root cause
                |
                v
        Minimal targeted change
                |
                v
        Run focused validation
                |
                v
         Create focused PR
                |
                v
        Maintainer review/merge
                |
                v
              main
```

GitHub custom agents are repository-level Markdown profiles under `.github/agents/`. GitHub documents `read`, `search`, `edit`, and `execute` as supported tool aliases; the profiles in this repository intentionally restrict each agent to those core capabilities. citeturn346133search0turn346133search1
