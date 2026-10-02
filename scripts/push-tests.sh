#!/usr/bin/env bash
set -Eeuo pipefail
T="$1"
declare -A MSG=(
[hyper-economy-bridge]="test: cover money arithmetic with 15 unit tests

Extracts all balance arithmetic into a Bukkit-free Ledger class so it can
be tested directly, then covers the cases where a defect silently creates
or destroys currency:

- concurrent deposits and withdrawals, asserting no lost updates and no
  negative balance under 16-thread contention
- overflow rejected via Math.addExact rather than wrapped, since a wrapped
  long turns a large deposit into free money
- transfers conserve total supply, and a failed credit refunds the debit

Validated by mutation: swapping the atomic compute for a read-modify-write
loses 57,000 of 80,000 units, which the concurrency test catches.

Also adds verify.sh, which builds, tests and asserts Java 21 bytecode."
[spigot-metric-exporter]="test: validate Prometheus exposition format

A malformed body does not raise; Prometheus drops the target and the
dashboard goes blank. These assert the format directly: every sample line
parses with matching HELP and TYPE, the body ends with a newline, no
metric name repeats, the disabled tile-entity sentinel is omitted rather
than plotted as -1, and a zero max-heap does not divide by zero.

Also adds verify.sh."
[chronos-daily-rewards]="test: cover streak transitions and timezone arithmetic

Asserts that a UTC day boundary and an Asia/Riyadh boundary genuinely
differ at 22:30Z, which is the reason the zone is configurable at all.
Also covers month end, year end, the 2024 leap day, a DST spring-forward,
and that a broken streak preserves the previous best.

Also adds verify.sh."
[mc-backup-daemon]="test: assert RCON freeze ordering with a mock server

Adds a mock Source RCON server that records received commands, so the
ordering that prevents corrupt backups is asserted rather than assumed:

    assert rcon_server.commands == ['save-off', 'save-all flush', 'save-on']

Validated by mutation: removing the flush, or disabling the finally block
that restores saving, both fail this test. Also covers auth rejection,
multi-packet response reassembly, retention pruning, and that a partial
archive is removed on failure.

verify.sh additionally performs a real round trip and diffs the restored
tree against the source."
)
DEFAULT="chore: add verify.sh for local validation

GitHub-hosted runners are unavailable on this account, so verification is
provided as a script to run locally rather than as a workflow that would
sit permanently red."

cd /tmp/mc/repos
for d in */; do
  n="${d%/}"
  (
    cd "$n"
    git add -A
    if git diff --cached --quiet; then echo "  $n  (no change)"; exit 0; fi
    msg="${MSG[$n]:-$DEFAULT}"
    git -c user.name="vndel" -c user.email="71823834+vndel@users.noreply.github.com" \
        commit -q -m "$msg"
    git push -q "https://${T}@github.com/vndel/${n}.git" main
    echo "  $n  pushed"
  )
done
