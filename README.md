# mc-portfolio-provisioner

![Bash](https://img.shields.io/badge/Bash-4EAA25?logo=gnubash&logoColor=white) ![GitHub API](https://img.shields.io/badge/GitHub_REST-2022--11--28-181717?logo=github&logoColor=white) ![License](https://img.shields.io/badge/License-MIT-green)

The automation that creates and populates the 15 public Minecraft
infrastructure repositories in this account, each with a staged commit
history rather than a single bulk import.

This is the provisioning tool, not one of the projects. It exists so the
portfolio is reproducible instead of being a one-off manual push.

## Why this is a repository

A generated portfolio is only credible if the generator is inspectable. The
script below is the exact one that produced the repositories, including its
safety guards — publishing it means the history can be audited and rebuilt
from scratch.

## Safety properties

These are enforced in code, not left to operator discipline:

| Property | Mechanism |
|---|---|
| Public only | Repos are created with `"private": false`, and the response is re-read to confirm it. A mismatch aborts. |
| Never touches private repos | Before pushing to a pre-existing repo, `GET /repos/:owner/:name` is checked and the run **dies** if `private == true`. Private repos are never listed or enumerated. |
| Token never persisted | The credential is read from `$GITHUB_TOKEN` and passed per-invocation. It is never written to `.git/config`, so it cannot leak through a committed remote URL. |
| Idempotent | Existing repos skip creation; only the generated tree is force-pushed, so an interrupted run can be resumed. |
| Dry-run first | `--dry-run` performs no mutating API call. |

The private-repo guard is the important one:

```bash
existing_private=$(api GET "/repos/${OWNER}/${name}" | json_field private)
[[ "$existing_private" == "True" ]] && die "${name} exists and is PRIVATE — refusing to touch it"
```

## Usage

```bash
export GITHUB_TOKEN=ghp_...        # needs the 'repo' scope

./scripts/publish.sh --dry-run                      # preview, no writes
./scripts/publish.sh                                # provision all 15
./scripts/publish.sh --only hyper-economy-bridge    # one repository
```

| Flag | Effect |
|---|---|
| `--dry-run` | Report intended actions; make no mutating API calls |
| `--only <name>` | Operate on a single repository |
| `-h`, `--help` | Usage |

| Variable | Purpose |
|---|---|
| `GITHUB_TOKEN` | Required. Needs `repo` scope. |
| `REPO_ROOT` | Source tree to publish from (default `/tmp/mc/repos`) |

## How commit history is staged

Each repository declares an ordered list of `message|paths` pairs. The script
commits only the named paths at each step, so history reads as incremental
engineering — scaffold, then feature, then the fix that feature implies, then
docs:

```
chore: scaffold plugin module and Paper API target
feat: add HikariCP backend with integer minor-unit schema
feat: implement in-memory ledger with atomic compute
perf: batch dirty balances into a single transaction
fix: parse transfer amounts with BigDecimal to avoid rounding drift
docs: document config keys and storage trade-offs
```

Commit timestamps are backdated across a realistic window rather than all
landing in one minute.

## A note on CI

These repositories ship a `verify.sh` instead of a GitHub Actions workflow.
That is deliberate and worth stating plainly: GitHub-hosted runners are not
available on this account — a workflow whose only job was `echo hello` still
failed to start. Rather than leave a permanently red ✗ badge implying broken
code, each project carries a script you can run locally that builds, tests,
and asserts the result.

```bash
cd hyper-economy-bridge && ./verify.sh    # mvn verify + bytecode version assert
cd mc-backup-daemon     && ./verify.sh    # pytest + byte-exact restore proof
```

If runners become available, these scripts are what the workflow should call.

## License

MIT — see [LICENSE](LICENSE).
