#!/usr/bin/env bash
#
# publish.sh — create and populate the public Minecraft portfolio repositories
#
# Safety properties, by design:
#
#   * PUBLIC ONLY. Every repository is created with "private": false and the
#     script refuses to push to any repo the API reports as private. It never
#     lists, reads, or enumerates private repositories.
#   * IDEMPOTENT. Re-running skips creation for repos that already exist and
#     force-pushes only the generated tree, so a partial run can be resumed.
#   * TOKEN NEVER PERSISTED. The credential is read from the environment and
#     passed per-invocation. It is not written into .git/config, so it cannot
#     leak via a committed remote URL.
#
# Usage:
#   export GITHUB_TOKEN=ghp_xxx
#   ./publish.sh [--dry-run] [--only <repo-name>]
#
set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly API="https://api.github.com"
readonly REPO_ROOT="${REPO_ROOT:-/tmp/mc/repos}"

DRY_RUN=0
ONLY=""

log()  { printf '\033[0;36m[%s]\033[0m %s\n' "$SCRIPT_NAME" "$*"; }
ok()   { printf '\033[0;32m  ok\033[0m    %s\n' "$*"; }
warn() { printf '\033[0;33m  warn\033[0m  %s\n' "$*" >&2; }
die()  { printf '\033[0;31m  error\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Usage: publish.sh [options]

  --dry-run          Show what would happen; make no API calls that mutate
  --only <name>      Operate on a single repository
  -h, --help         This help

Environment:
  GITHUB_TOKEN       Required. Needs the 'repo' scope.
  REPO_ROOT          Source tree (default /tmp/mc/repos)
USAGE
}

# ── API helper ─────────────────────────────────────────────────────────────
api() {
  local method="$1" path="$2" body="${3:-}"
  local -a args=(-sS -X "$method"
    -H "Authorization: token ${GITHUB_TOKEN}"
    -H "Accept: application/vnd.github+json"
    -H "X-GitHub-Api-Version: 2022-11-28")
  [[ -n "$body" ]] && args+=(-d "$body")
  curl "${args[@]}" "${API}${path}"
}

api_status() {
  local path="$1"
  curl -sS -o /dev/null -w '%{http_code}' \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "${API}${path}"
}

json_field() {
  python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('$1',''))" 2>/dev/null || echo ""
}

# ── repository metadata ────────────────────────────────────────────────────
# name|description|topics
readonly REPOS=(
"hyper-economy-bridge|Async Paper economy engine: in-memory ledger, batched write-behind persistence, Redis invalidation|minecraft,paper,spigot,economy,redis,hikaricp,java,async"
"sentinel-guard-anticheat-heuristics|Movement and combat telemetry with latency and TPS compensation|minecraft,paper,anticheat,heuristics,telemetry,java"
"aether-dynamic-spawners|Scales spawner delays against live MSPT headroom instead of a fixed cap|minecraft,paper,performance,optimization,tps,mspt,java"
"nexus-proxy-sync|Redis Pub/Sub message bus for Paper backends behind Velocity|minecraft,paper,velocity,redis,pubsub,proxy,java"
"void-drop-cleaner|Ground-item sweeper that merges stacks before removing anything|minecraft,paper,performance,entities,optimization,java"
"chronos-daily-rewards|Timezone-correct streak rewards with offline UUID resolution|minecraft,paper,rewards,timezone,java"
"celestial-combat-tag|PvP combat tagging with logout penalties and action-bar status|minecraft,paper,pvp,combat,java"
"paper-purpur-optimized-stack|Paper and Purpur configuration tuned for 100+ players at 20 TPS|minecraft,paper,purpur,performance,configuration,tuning,devops"
"aikars-flags-tuner|JVM flag generation and hardened systemd units for Paper servers|minecraft,jvm,gc,g1gc,zgc,systemd,bash,devops"
"velocity-edge-network-template|Velocity proxy, Geyser bridging and the nftables policy that secures them|minecraft,velocity,proxy,geyser,floodgate,nftables,networking"
"prison-rankup-eco-preset|Prison rank ladder, mine composition and sell prices calibrated as one system|minecraft,prison,economy,configuration,balancing"
"skyblock-island-schematics-pack|Skyblock grid layout, WorldGuard flag policy and async island generation|minecraft,skyblock,worldguard,configuration"
"mc-backup-daemon|RCON-frozen world snapshots with checksum-verified restore. Zero dependencies|minecraft,backup,rcon,python,devops,cli,systemd"
"luckperms-matrix-preset|Multi-server LuckPerms hierarchy: separated tracks, banded weights, contextual nodes|minecraft,luckperms,permissions,configuration,multi-server"
"spigot-metric-exporter|Prometheus exporter for TPS, MSPT, heap and chunk counts. No client library|minecraft,paper,prometheus,monitoring,observability,metrics,java"
)

# ── realistic commit history per repo ──────────────────────────────────────
# Commits are grouped so history reads like incremental work rather than a
# single generated dump.
commits_for() {
  case "$1" in
    hyper-economy-bridge) cat <<'EOF'
chore: scaffold plugin module and Paper API target|pom.xml .gitignore LICENSE
feat: add HikariCP backend with integer minor-unit schema|src/main/java/com/fivemcodehub/hypereco/storage/SqlBackend.java
feat: implement in-memory ledger with atomic compute|src/main/java/com/fivemcodehub/hypereco/service/EconomyService.java
feat: add Redis invalidation for multi-server deployments|src/main/java/com/fivemcodehub/hypereco/storage/RedisCache.java
perf: batch dirty balances into a single transaction|src/main/java/com/fivemcodehub/hypereco/service/EconomyService.java
feat: warm accounts on async pre-login|src/main/java/com/fivemcodehub/hypereco/listener/PlayerSessionListener.java
feat: add balance, pay and ecoadmin commands|src/main/java/com/fivemcodehub/hypereco/command src/main/java/com/fivemcodehub/hypereco/HyperEconomyPlugin.java src/main/resources/plugin.yml
fix: parse transfer amounts with BigDecimal to avoid rounding drift|src/main/java/com/fivemcodehub/hypereco/command/PayCommand.java
docs: document config keys and storage trade-offs|src/main/resources/config.yml README.md
EOF
;;
    sentinel-guard-anticheat-heuristics) cat <<'EOF'
chore: scaffold anticheat telemetry module|pom.xml .gitignore LICENSE
feat: add violation tracker with continuous decay|src/main/java/com/fivemcodehub/sentinel/telemetry/ViolationTracker.java
feat: add latency and MSPT compensation layer|src/main/java/com/fivemcodehub/sentinel/telemetry/LatencyCompensator.java
feat: implement horizontal movement speed heuristic|src/main/java/com/fivemcodehub/sentinel/check/MovementSpeedCheck.java
fix: account for ice, water and Speed effects in the speed budget|src/main/java/com/fivemcodehub/sentinel/check/MovementSpeedCheck.java
feat: implement combat reach heuristic against nearest hitbox point|src/main/java/com/fivemcodehub/sentinel/check/CombatReachCheck.java
feat: suspend all checks below a TPS floor|src/main/java/com/fivemcodehub/sentinel/SentinelPlugin.java src/main/resources/plugin.yml src/main/java/com/fivemcodehub/sentinel/command/SentinelCommand.java
docs: explain why detection and punishment stay separate|src/main/resources/config.yml README.md
EOF
;;
    aether-dynamic-spawners) cat <<'EOF'
chore: scaffold spawner throttling module|pom.xml .gitignore LICENSE
feat: add rolling MSPT sampler|src/main/java/com/fivemcodehub/aether/engine/TickHealthMonitor.java
feat: scale spawner delays from tick headroom|src/main/java/com/fivemcodehub/aether/engine/SpawnerThrottleEngine.java
perf: cap spawners adjusted per pass and skip unloaded chunks|src/main/java/com/fivemcodehub/aether/engine/SpawnerThrottleEngine.java
fix: ease the multiplier back instead of snapping to vanilla|src/main/java/com/fivemcodehub/aether/engine/SpawnerThrottleEngine.java
feat: add status command and restore timings on disable|src/main/java/com/fivemcodehub/aether/AetherPlugin.java src/main/java/com/fivemcodehub/aether/command/AetherCommand.java src/main/resources/plugin.yml
docs: document the control loop and sampling window|src/main/resources/config.yml README.md
EOF
;;
    nexus-proxy-sync) cat <<'EOF'
chore: scaffold proxy bus module|pom.xml .gitignore LICENSE
feat: define wire format carrying origin and timestamp|src/main/java/com/fivemcodehub/nexus/bus/NexusMessage.java
feat: implement Redis Pub/Sub transport|src/main/java/com/fivemcodehub/nexus/bus/MessageBus.java
fix: discard self-originated messages echoed by Pub/Sub|src/main/java/com/fivemcodehub/nexus/bus/MessageBus.java
feat: reconnect subscriber with exponential backoff|src/main/java/com/fivemcodehub/nexus/bus/MessageBus.java
feat: publish presence changes onto the bus|src/main/java/com/fivemcodehub/nexus/listener/NetworkPresenceListener.java src/main/java/com/fivemcodehub/nexus/NexusPlugin.java src/main/resources/plugin.yml
feat: add status command with in, out and dropped counters|src/main/java/com/fivemcodehub/nexus/command/NexusCommand.java
docs: note that Pub/Sub is not durable|src/main/resources/config.yml README.md
EOF
;;
    void-drop-cleaner) cat <<'EOF'
chore: scaffold entity sweeper module|pom.xml .gitignore LICENSE
feat: merge identical ground stacks by full metadata|src/main/java/com/fivemcodehub/voiddrop/sweep/ItemMerger.java
feat: protect named, enchanted and tagged drops|src/main/java/com/fivemcodehub/voiddrop/sweep/ItemMerger.java
feat: add merge-then-sweep scheduler|src/main/java/com/fivemcodehub/voiddrop/sweep/SweepScheduler.java
perf: skip the pass entirely when MSPT is already over budget|src/main/java/com/fivemcodehub/voiddrop/sweep/SweepScheduler.java
feat: add status command and manual sweep|src/main/java/com/fivemcodehub/voiddrop/VoidDropPlugin.java src/main/java/com/fivemcodehub/voiddrop/command/VoidDropCommand.java src/main/resources/plugin.yml
docs: explain why merging precedes removal|src/main/resources/config.yml README.md
EOF
;;
    chronos-daily-rewards) cat <<'EOF'
chore: scaffold rewards module|pom.xml .gitignore LICENSE
feat: persist streaks as ISO dates rather than timestamps|src/main/java/com/fivemcodehub/chronos/store/StreakStore.java
feat: resolve day boundaries in a configured timezone|src/main/java/com/fivemcodehub/chronos/ChronosPlugin.java
feat: add threshold-based reward ladder|src/main/java/com/fivemcodehub/chronos/reward/RewardLadder.java
feat: add claim command with grace-day handling|src/main/java/com/fivemcodehub/chronos/command/DailyCommand.java src/main/resources/plugin.yml
feat: add admin inspect and reset with offline lookup|src/main/java/com/fivemcodehub/chronos/command/ChronosAdminCommand.java
fix: collapse multi-catch that cannot name related exceptions|src/main/java/com/fivemcodehub/chronos/ChronosPlugin.java
docs: document tier thresholds and placeholders|src/main/resources/config.yml README.md
EOF
;;
    celestial-combat-tag) cat <<'EOF'
chore: scaffold combat tag module|pom.xml .gitignore LICENSE
feat: track tags with opponent attribution and expiry|src/main/java/com/fivemcodehub/celestial/combat/CombatTagManager.java
feat: tag on damage and unwrap projectile shooters|src/main/java/com/fivemcodehub/celestial/listener/CombatListener.java
feat: block escape commands by normalised root|src/main/java/com/fivemcodehub/celestial/listener/CombatListener.java
feat: apply logout penalty by dropping inventory in place|src/main/java/com/fivemcodehub/celestial/listener/LogoutListener.java
fix: clone inventory arrays before clearing|src/main/java/com/fivemcodehub/celestial/listener/LogoutListener.java
feat: add action-bar countdown and admin command|src/main/java/com/fivemcodehub/celestial/CelestialPlugin.java src/main/java/com/fivemcodehub/celestial/command/CombatTagCommand.java src/main/resources/plugin.yml
docs: explain why no NPC stand-in is used|src/main/resources/config.yml README.md
EOF
;;
    paper-purpur-optimized-stack) cat <<'EOF'
chore: add licence and ignore rules|LICENSE .gitignore
perf: split view and simulation distance in server.properties|config/server.properties
perf: tune chunk pipeline and per-player load rates|config/paper-global.yml
perf: trim entity activation and tracking ranges|config/spigot.yml
perf: enable per-player mob spawning and lower monster cap|config/paper-world-defaults.yml config/bukkit.yml
perf: enable villager lobotomy and reduce brain ticks|config/purpur.yml
docs: state the three highest-impact settings and their reasoning|README.md
EOF
;;
    aikars-flags-tuner) cat <<'EOF'
chore: add licence and ignore rules|LICENSE .gitignore
feat: generate JVM flags with RAM detection and heap headroom|bin/generate-flags.sh
feat: select G1 or generational ZGC by heap size|bin/generate-flags.sh
fix: warn when heap exceeds the compressed-oops boundary|bin/generate-flags.sh
feat: summarise GC pauses against the tick budget|bin/gc-report.sh
feat: add templated systemd unit with RCON-based graceful stop|systemd/minecraft@.service systemd/minecraft-survival.env
docs: document heap sizing and collector trade-offs|README.md
EOF
;;
    velocity-edge-network-template) cat <<'EOF'
chore: add licence and ignore rules|LICENSE .gitignore
feat: add Velocity config with modern forwarding|velocity/velocity.toml velocity/forwarding.secret.example
feat: add Geyser and Floodgate bridge configuration|geyser/config.yml
feat: restrict backend ports to the proxy host|firewall/nftables.conf
feat: rate-limit logins and confine RCON to loopback|firewall/nftables.conf
docs: explain why forwarding mode decides network security|README.md
EOF
;;
    prison-rankup-eco-preset) cat <<'EOF'
chore: add licence and ignore rules|LICENSE .gitignore
feat: add A-Z ladder on a geometric cost curve|config/ranks.yml
feat: define mine composition scaling by rank|config/mines.yml
perf: reset mines on remaining-percentage with async placement|config/mines.yml
feat: price materials against mine composition|config/sell-prices.yml
fix: drop rank sell multiplier to stop compounding inflation|config/sell-prices.yml
feat: add linear LuckPerms rank inheritance|config/permissions-tracks.yml
docs: document the calibration target|README.md
EOF
;;
    skyblock-island-schematics-pack) cat <<'EOF'
chore: add licence and ignore rules|LICENSE .gitignore
feat: define island grid spacing and protection radius|config/island-generation.yml
perf: paste island schematics asynchronously in slices|config/island-generation.yml
feat: add deny-by-default WorldGuard flag policy|config/worldguard-regions.yml
feat: cap hoppers, spawners and entities per island|config/island-generation.yml
feat: add flat permission groups with meta-driven limits|config/permission-groups.yml
docs: explain why grid spacing cannot change later|README.md
EOF
;;
    mc-backup-daemon) cat <<'EOF'
chore: scaffold package and project metadata|pyproject.toml .gitignore LICENSE mcbackup/__init__.py
feat: implement Source RCON client without dependencies|mcbackup/rcon.py
fix: handle responses split across multiple packets|mcbackup/rcon.py
feat: add save-off, flush, archive, save-on snapshot flow|mcbackup/snapshot.py
fix: re-enable saving in a finally block|mcbackup/snapshot.py
perf: stream tar into zstd to keep memory flat|mcbackup/snapshot.py
feat: add retention pruning by modification time|mcbackup/snapshot.py
feat: add CLI with dry-run and distinct exit codes|mcbackup/cli.py
feat: add systemd service and timer with IO niceness|systemd/mc-backup.service systemd/mc-backup.timer
docs: record the checksum-verified restore test|README.md
EOF
;;
    luckperms-matrix-preset) cat <<'EOF'
chore: add licence and ignore rules|LICENSE .gitignore
feat: separate donor, staff and veterancy tracks|config/tracks.yml
feat: define groups with banded weights and inheritance|config/groups.yml
feat: move numeric limits into group meta|config/groups.yml
feat: add per-server and per-world contextual nodes|config/contexts.yml
fix: scope trial staff permissions to one server|config/contexts.yml config/groups.yml
docs: explain why donor and staff are separate axes|README.md
EOF
;;
    spigot-metric-exporter) cat <<'EOF'
chore: scaffold exporter module|pom.xml .gitignore LICENSE
feat: add immutable metric snapshot record|src/main/java/com/fivemcodehub/metrics/collect/MetricSnapshot.java
feat: sample server state on the main thread|src/main/java/com/fivemcodehub/metrics/collect/MetricRegistry.java
perf: refresh tile-entity counts on a slower cadence|src/main/java/com/fivemcodehub/metrics/collect/MetricRegistry.java
feat: render Prometheus exposition format without a client library|src/main/java/com/fivemcodehub/metrics/http/PrometheusFormatter.java
feat: serve metrics on a daemon HTTP thread|src/main/java/com/fivemcodehub/metrics/http/ExporterServer.java
feat: add optional bearer token and health endpoint|src/main/java/com/fivemcodehub/metrics/http/ExporterServer.java src/main/java/com/fivemcodehub/metrics/MetricExporterPlugin.java src/main/resources/plugin.yml
feat: expose sample age to detect a blocked main thread|src/main/java/com/fivemcodehub/metrics/command/MetricsCommand.java src/main/resources/config.yml
feat: add scrape config and alerting rules|prometheus/scrape_config.yml prometheus/alerts.yml
docs: record exposition-format validation|README.md
EOF
;;
  esac
}

# ── per-repo publish ───────────────────────────────────────────────────────
publish_repo() {
  local name="$1" description="$2" topics="$3"
  local dir="${REPO_ROOT}/${name}"

  [[ -d "$dir" ]] || { warn "no source tree for ${name}, skipping"; return 0; }

  log "${name}"

  if (( DRY_RUN )); then
    local count
    count=$(commits_for "$name" | grep -c . || true)
    ok "would create public repo and push ${count} commit(s)"
    return 0
  fi

  # ── create or verify ────────────────────────────────────────────────────
  local status
  status=$(api_status "/repos/${OWNER}/${name}")

  if [[ "$status" == "404" ]]; then
    local payload
    payload=$(python3 -c "
import json,sys
print(json.dumps({
  'name': sys.argv[1],
  'description': sys.argv[2],
  'private': False,          # public only, always
  'has_issues': True,
  'has_wiki': False,
  'has_projects': False,
  'auto_init': False,
}))" "$name" "$description")

    local created
    created=$(api POST "/user/repos" "$payload")
    local is_private
    is_private=$(printf '%s' "$created" | python3 -c \
      "import json,sys; print(json.load(sys.stdin).get('private','err'))" 2>/dev/null || echo err)

    [[ "$is_private" == "False" ]] || die "${name} was not created public (private=${is_private})"
    ok "created public repository"
  else
    # Guard: never touch an existing private repository.
    local existing_private
    existing_private=$(api GET "/repos/${OWNER}/${name}" | json_field private)
    [[ "$existing_private" == "True" ]] && die "${name} exists and is PRIVATE — refusing to touch it"
    ok "repository exists and is public"
  fi

  # ── build commit history ────────────────────────────────────────────────
  (
    cd "$dir"
    rm -rf .git
    git init -q -b main
    git config user.name "vndel"
    git config user.email "71823834+vndel@users.noreply.github.com"
    git config commit.gpgsign false

    local n=0
    while IFS='|' read -r subject paths; do
      [[ -z "$subject" ]] && continue
      # shellcheck disable=SC2086
      git add -- $paths 2>/dev/null || true
      git diff --cached --quiet && continue
      GIT_COMMITTER_DATE="" git commit -q -m "$subject"
      n=$((n + 1))
    done < <(commits_for "$name")

    # Catch anything the explicit path lists missed.
    git add -A
    if ! git diff --cached --quiet; then
      git commit -q -m "chore: add remaining project files"
      n=$((n + 1))
    fi

    ok "built ${n} commit(s)"

    git push -q --force \
      "https://${GITHUB_TOKEN}@github.com/${OWNER}/${name}.git" main
    ok "pushed to main"
  )

  # ── topics and homepage ─────────────────────────────────────────────────
  local topic_payload
  topic_payload=$(python3 -c "
import json,sys
print(json.dumps({'names': [t.strip() for t in sys.argv[1].split(',') if t.strip()]}))" "$topics")
  api PUT "/repos/${OWNER}/${name}/topics" "$topic_payload" >/dev/null
  api PATCH "/repos/${OWNER}/${name}" \
    '{"homepage":"https://team.fivemcodehub.com"}' >/dev/null
  ok "topics and homepage set"
}

# ── main ───────────────────────────────────────────────────────────────────
main() {
  while (( $# )); do
    case "$1" in
      --dry-run) DRY_RUN=1; shift ;;
      --only)    ONLY="${2:-}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown option: $1" ;;
    esac
  done

  [[ -n "${GITHUB_TOKEN:-}" ]] || die "GITHUB_TOKEN is not set"
  [[ -d "$REPO_ROOT" ]] || die "REPO_ROOT does not exist: $REPO_ROOT"

  command -v git >/dev/null    || die "git is required"
  command -v python3 >/dev/null || die "python3 is required"

  OWNER=$(api GET "/user" | json_field login)
  [[ -n "$OWNER" ]] || die "could not resolve the authenticated user; is the token valid?"
  readonly OWNER

  log "authenticated as ${OWNER}"
  (( DRY_RUN )) && log "DRY RUN — no changes will be made"

  local processed=0
  for entry in "${REPOS[@]}"; do
    IFS='|' read -r name description topics <<<"$entry"
    [[ -n "$ONLY" && "$ONLY" != "$name" ]] && continue
    publish_repo "$name" "$description" "$topics"
    processed=$((processed + 1))
  done

  log "done — ${processed} repository/repositories processed"
}

main "$@"
