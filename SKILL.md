# SKILL.md - AI Agent Infra with YashanDB

> **Version:** 4.3.1 | **Driver:** yaspy 1.2.1 | **DB:** YashanDB 23.5.4+ (崖山数据库)

This is the operations guide for the AI Agent Infra with YashanDB
release package. It covers everything an operator (human or AI Agent)
needs to deploy, configure, start, register against, and operate this
edition.

> **Product brand:** Chuanxu (川序) · **Product:** AI Agent Management Platform
>
> **Technical project:** AI Agent Infra with DB. The database-specific package name
> identifies the YashanDB adapter and edition; it is not a separate product
> brand.

This package is **Skill-first and framework-neutral**. Any Agent runtime that
can install or read `SKILL.md` and execute the packaged HTTP, MCP, or CLI
workflows can use the platform; OpenClaw and Hermes Agent are confirmed
integration examples. The runtime does not need to be created by this
platform. Registration and authentication are still required before an Agent
enters the managed inventory, identity, permission, and audit scope.

## 1. Overview

AI Agent Infra with DB is the technical foundation of the **Chuanxu AI Agent
Management Platform**, built on **YashanDB 23.5.4+** (崖山数据库). It
collapses the conventional
"Redis + vector DB + graph DB + object store" stack into a single
YashanDB kernel - leveraging VECTOR columns for embeddings, SEARCH INDEX
for full-text search, Role-Based Access Control (RBAC) for per-agent
isolation, the built-in crypto package for column encryption, and
DBMS_SCHEDULER for scheduled jobs.

YashanDB (崖山数据库) is a product of 北京崖山科技有限公司 (Beijing Yashan
Technology Co., Ltd.). This edition uses the `yaspy` Python driver.

| Edition             | Port | License          |
|---------------------|------|------------------|
| Community           | 8002 (default, configurable) | Apache 2.0       |
| Enterprise          | 8003 (default, configurable) | BSL 1.1          |

Enterprise adds: registered-Agent governance, resource policies and bounded
grants, server-attributed N-of-M approvals, emergency control, risk-based audit
and evidence export, per-agent encryption keys, LDAP auth, compliance logs,
skill tokens, and orchestrator approvals.

v4.3.1 requires every human and external or platform-hosted Agent to resolve to
an active database Principal before using non-bootstrap APIs. Agent enrollment
uses a one-time user-sponsored token; Business Agents receive neither database
credentials nor a Schema Owner fallback. The Enterprise resource catalog
is authoritative for classification; unknown or sensitive resources without an
explicit policy are denied. Approval, emergency, audit, retention, legal-hold,
and evidence-export controls are enforced by the server and database rather
than by Dashboard visibility.

The Organization workspace is a governed query and change interface. Agents
may discover only organization facts allowed by their authenticated Principal
and `organizations.*` scope. Reading this Skill does not grant graphical edit,
Human administration, directory synchronization, or publication authority.
Relational facts remain authoritative; the native graph is a projection only.

## 2. Package Contents

After extracting the release zip, you have:

```
AI-Agent-Infra-with-YashanDB-{Community,Enterprise}-Edition/
├── SKILL.md                        # this file
├── CHANGELOG.md                    # full version history
├── RELEASE_NOTES_v4.3.1.md   # this release's notes
├── NOTICE                          # third-party attributions
├── LICENSE  /  LICENSE_ENTERPRISE  # edition-specific license
├── requirements.txt                # pinned Python deps
├── config.example.json             # placeholder config template
├── start_web_server.sh             # server control script
├── docs/                           # deep-dive docs
│   ├── introduction_zh.md          # Chinese project introduction
│   ├── architecture.md
│   ├── api-reference.md
│   ├── security.md
│   ├── deployment.md
│   └── ...
├── vendor/                         # bundled wheels + yaspy native libs; verify before offline install
│   └── yaspy/                      # yaspy driver + YashanDB client libs
│       ├── yaspy.cpython-314-x86_64-linux-gnu.so
│       └── client_lib/             # *.so.1.4.100 (symlinks created at install)
└── scripts/
    ├── config_wizard.sh            # first-run interactive config prompt
    ├── install_offline.sh          # install vendor/ wheels (no PyPI)
    ├── install_yaspy.sh            # install yaspy driver + client libs
    ├── verify_deps.py              # pre-flight dependency checker
    ├── deploy_yashandb.py          # pure-Python SQL deploy
    ├── agent_bootstrap.py          # Business Agent registration CLI
    ├── deploy/                     # SQL scripts (run in order)
    │   ├── 1_schema.sql            #   tables, indexes, partitions
    │   ├── 2_api.sql               #   PL/SQL packages (API layer)
    │   ├── 3_jobs.sql              #   DBMS_SCHEDULER jobs
    │   ├── 4_harness_templates.sql #   agent harness templates
    │   ├── 4_grants.sql            #   End User grants
    │   ├── 8_v4_1_0_registration.sql # registered-Agent boundary (Community)
    │   ├── 8_v4_1_0_governance.sql   # registration + governance (Enterprise)
    │   ├── 9_v4_2_0_graph_engineering.sql
    │   ├── 10_v4_2_0_graph_runtime.sql
    │   ├── 11_v4_2_0_graph_control.sql
    │   ├── 12_v4_2_0_graph_edge_scope.sql
    │   ├── 13_v4_2_0_scheduler_ha.sql # Enterprise overlay only
    │   ├── 14_v4_2_0_graph_triggers.sql
    │   ├── 15_v4_2_1_executor_registry.sql # internal closure
    │   ├── 16_v4_3_0_identity_channels.sql
    │   ├── 17_v4_3_0_governance_lifecycle.sql
    │   ├── 18_v4_3_0_security_lifecycle.sql
    │   └── 19_v4_3_1_organization_governance.sql
    ├── lib/                        # business modules
    │   ├── connection.py           #   yaspy connection pool (VECTOR array->string)
    │   ├── config.py               #   config loader (auto-decrypts)
    │   ├── connection_crypto.py    #   PBKDF2 + AES-256-GCM
    │   ├── agent_api.py            #   End User management
    │   └── ...                     #   knowledge/graph/memory/loop/...
    ├── tools/
    │   └── encrypt_config.py       # manual encrypt/decrypt CLI
    ├── tests/                      # pytest suite
    └── visualization/
        ├── server.py               # HTTP server (single source of VERSION)
        ├── static/                 # CSS, JS
        └── templates/              # HTML pages
```

## 3. Prerequisites

| Component | Minimum | Notes |
|-----------|---------|-------|
| YashanDB | 23.5.4+ (崖山数据库) | verify: `SELECT version FROM v$instance;` |
| Python | 3.8+ (3.14 recommended) | yaspy driver needs 3.8+ |
| yaspy driver | 1.2.1+ | bundled in `vendor/yaspy/` |
| YashanDB client libs | 1.4.100 | bundled in `vendor/yaspy/client_lib/` |
| Crypto package grant | required | ask DBA to grant execute on the built-in crypto package |
| Memory | 2 GB free | for connection pool + vector search |

## 4. Installation (offline-capable runtime)

The compiled Web assets run without Node.js, npm, or network access. Python
installation is offline only when every requirement in `requirements.txt` has
an exact compatible wheel in `vendor/`; `verify_deps.py` is the release gate.
**Two install steps are required** (in this order):

```bash
# 1. Extract the zip
unzip AI-Agent-Infra-with-YashanDB-Enterprise-Edition-v4.3.1.zip
cd AI-Agent-Infra-with-YashanDB-Enterprise-Edition

# Select any accessible Python 3.14+ runtime; no vendor-specific path is required.
source scripts/python_runtime.sh
export PYTHON_BIN="$(cx_resolve_python)"
cx_prepare_python_environment "$PYTHON_BIN"

# 2. Install yaspy driver + YashanDB client libraries (REQUIRED FIRST)
bash scripts/install_yaspy.sh
# -> copies yaspy.cpython-*.so to Python site-packages
# -> copies client_lib/*.so.1.4.100 to ~/.yashandb/client/lib/
# -> recreates the .so and .so.MAJOR symlinks (cannot survive zip archive)
# -> exports LD_LIBRARY_PATH in ~/.bashrc

# 3. Install remaining Python dependencies from vendor/
bash scripts/install_offline.sh

# 4. Verify all dependencies are present
"$PYTHON_BIN" scripts/verify_deps.py
```

The installer fails closed when a required wheel is missing or incompatible;
obtain the missing release dependencies from the approved internal mirror
before retrying.

`vendor/` may contain both the upstream `cryptography==49.0.0` wheel for
glibc 2.34+ and the RHEL 8/glibc 2.28 source-built wheel. The installer and
`verify_deps.py` select the compatible one automatically. Customers on newer
systems do not need to rebuild cryptography; the reproducible source-build
procedure is documented in `docs/cryptography-build.md`.
The current v4.3.1 archive includes the verified glibc 2.28 wheel; do not
rename the `manylinux_2_34` wheel or substitute an older cryptography release.

`deploy_yashandb.py` automatically invokes `install_yaspy.sh` before
deploying, so you can skip step 2 if you go straight to schema deployment.

## 5. Configuration

The zip ships **`config.example.json`** with `<PLACEHOLDER>` values only -
real credentials are NEVER bundled. Two ways to produce a runnable
`config.json`:

### Path A: Interactive wizard (recommended for first run)
```bash
./start_web_server.sh start
# -> wizard auto-detects <PLACEHOLDER> tokens and prompts for:
#     database: user / password / dsn (host:port/service)
#     llm:      api_url / model / api_key
#     embedding: api_url / model / dimension
# -> writes config.json
# -> server then auto-encrypts sensitive sections on first boot
```
Standalone invocation:
```bash
bash scripts/config_wizard.sh
```

### Path B: Manual edit
```bash
cp config.example.json config.json
vim config.json   # replace every <PLACEHOLDER> with a real value
./start_web_server.sh start
```

### Auto-encryption
On first startup, `auto_encrypt_config()` encrypts sensitive fields in the
`database`, `security`, `llm`, and `model_routing` sections of `config.json`
as AES-256-GCM `_encrypted` blobs. This includes database credentials, API
keys, and `security.secret_key`; non-sensitive policy remains readable. The
server enforces owner-only (`0600`) permissions and decrypts transparently.

Manual encrypt / decrypt:
```bash
"$PYTHON_BIN" scripts/tools/encrypt_config.py encrypt config.json
"$PYTHON_BIN" scripts/tools/encrypt_config.py decrypt config.json
```

## 6. Database Schema Deployment

The release includes `scripts/deploy_yashandb.py` - a pure-Python SQL
deployment tool. It runs the SQL scripts in `scripts/deploy/` in order,
and automatically invokes `install_yaspy.sh` first if needed.

```bash
# Deploy schema + API packages + jobs + grants (Enterprise)
"$PYTHON_BIN" scripts/deploy_yashandb.py <user> <password> <host>:1688/<service> \
    scripts/deploy/1_schema.sql \
    scripts/deploy/2_api.sql \
    scripts/deploy/3_jobs.sql \
    scripts/deploy/4_harness_templates.sql \
    scripts/deploy/4_grants.sql
```

Verify deployment:
```bash
curl http://localhost:<port>/api/agent/deployment-check
```

The schema script `1_schema.sql` is idempotent - it auto-aborts if
`SYSTEM_CONFIG.schema_version` already exists.

For the integrated v4.3.0 profile, use `scripts/migration_runner.py` for the
additive migration tail. Community applies these nine scripts in order:
`9_v4_2_0_graph_engineering.sql`, `10_v4_2_0_graph_runtime.sql`,
`11_v4_2_0_graph_control.sql`, `12_v4_2_0_graph_edge_scope.sql`,
`14_v4_2_0_graph_triggers.sql`, `15_v4_2_1_executor_registry.sql`,
`16_v4_3_0_identity_channels.sql`, and
`17_v4_3_0_governance_lifecycle.sql`, and
`18_v4_3_0_security_lifecycle.sql`. Enterprise inserts
`13_v4_2_0_scheduler_ha.sql` between `12` and `14`, for ten scripts total.
The internal `15` step is part of v4.3.0 and is not a public v4.2.1 release.

## 7. Start the Server

```bash
./start_web_server.sh start     # start (calls wizard if config.json missing)
./start_web_server.sh status    # check status
./start_web_server.sh stop      # stop
./start_web_server.sh restart   # restart
```

Access the dashboard at `http://<host>:<port>` - login: `admin / <password>`
(the password is set in `config.json` under `security.admin_password`).

If the server crashes on startup with `import yaspy` errors, ensure
`install_yaspy.sh` has been run and `LD_LIBRARY_PATH` includes
`~/.yashandb/client/lib/`.

## 8. Business Agent Registration

Business Agents register against the Admin Agent to obtain encrypted
database credentials:

```bash
# Register a new Business Agent
"$PYTHON_BIN" scripts/agent_bootstrap.py register \
    --agent-id MY_AGENT \
    --agent-name "My Business Agent" \
    --admin-token AT_xxx \
    --admin-url http://<admin-host>:<port>

# Test the resulting connection
"$PYTHON_BIN" scripts/agent_bootstrap.py test

# Recover if the agent crashed and lost credentials
"$PYTHON_BIN" scripts/agent_bootstrap.py recover \
    --agent-id MY_AGENT \
    --recovery-code RC-XXXX-XXXX-XXXX \
    --admin-token AT_xxx \
    --admin-url http://<admin-host>:<port>
```

The bootstrap CLI auto-detects the driver from `agent_config.json`'s
`db_type` field (set to `"yashandb"` by this adapter) and imports `yaspy`.

Each Business Agent receives its own YashanDB End User. The End User
password is stored encrypted in `SYSTEM_CONFIG` and distributed via the
registration API (encrypted with `admin_token` as the PBKDF2 salt source).

## 9. API Reference

Once the server is running, these endpoints are available:

| Category | Endpoint | Method | Description |
|----------|----------|--------|-------------|
| **System** | `/api/health` | GET | Health check |
| **Auth** | `/api/login` | POST | Admin login |
| **Agents** | `/api/agents` | GET/POST | List / register agents |
| **Memory** | `/api/memory` | GET/POST | Memory search / store |
| **Knowledge** | `/api/knowledge` | GET/POST | Knowledge base CRUD |
| **Graph** | `/api/graph/all` | GET | Full graph |
| **Graph** | `/api/graph/search` | POST | Graph search |
| **Graph** | `/api/graph/neighbors` | POST | Neighbor traversal |
| **Tasks** | `/api/tasks` | GET/POST | Task management |
| **Branches** | `/api/branches` | GET/POST | Context branches |
| **Monitor** | `/api/monitor/overview` | GET | System overview |
| **Monitor** | `/api/monitor/agents` | GET | Agent status |
| **Portal** | `/portal/api/login` | POST | Portal user login |
| **Portal** | `/portal/api/chat/send` | POST | Portal chat (SSE) |
| **Enterprise** | `/api/admin/crypto/rotate` | POST | Rotate encryption keys |
| **Enterprise** | `/api/approvals` | GET/POST | Approval requests |
| **Enterprise** | `/api/audit` | GET | Audit trail |
| **Enterprise** | `/api/governance/resources` | GET/POST | Governed resource catalog |
| **Enterprise** | `/api/governance/decide` | POST | Server-side policy decision |
| **Enterprise** | `/api/governance/approvals/{id}/decision` | POST | N-of-M approval decision |
| **Enterprise** | `/api/governance/emergency` | GET/POST | Emergency disable and retry |
| **Enterprise** | `/api/governance/evidence/export` | GET | Scoped evidence export |
| **Agent Protocol** | `/ap/v1/agent/tasks` | POST | Agent Protocol compat |

Full API details: `docs/api-reference.md`.

### Canonical And Legacy Entry Points

New integrations use the authenticated FastAPI service (`web_app:app`) and
its Principal-aware `/api/auth/*`, resource, Graph, Channel, Barrier, Gateway,
and governance routes, or the equivalent HTTP/MCP/Skill workflow. The
established Dashboard, Portal, and Agent paths are retained through the
request-local compatibility bridge to `visualization/server.py`; the bridge
does not open a second listener or grant direct database access. Legacy callers
remain subject to session, CSRF, Agent identity, and permission checks. The
`production` runtime profile exposes the integrated v4.3.1 stable core and is
the current production recommendation; the v4.3.1 release and closure evidence
are PASS. `graph-preview` and `development` remain explicitly controlled
profiles for experimental capabilities.

## 10. Security Model

| Layer | Mechanism |
|-------|-----------|
| Row-level isolation | **Role-Based Access Control (RBAC)** via per-agent End User roles |
| Column encryption | YashanDB built-in crypto package (AES-256-GCM) |
| Auth | Local users + LDAP (Enterprise) |
| Audit | `entity_access_log` + `audit_api` (Enterprise) |
| Governance | Resource policy, bounded grants, approvals, emergency control (Enterprise) |

Each Business Agent receives its own YashanDB End User. The End User
password is stored encrypted in `SYSTEM_CONFIG` and distributed via the
registration API. The Schema Owner credential is Admin-only; Business Agent
authentication and failed policy checks never fall back to the Admin pool.

## 11. Testing

```bash
# Run the full test suite
"$PYTHON_BIN" -m pytest scripts/tests/ -v

# Or the legacy runner
cd scripts && "$PYTHON_BIN" -m tests.test_all
```

Tests use the configured `config.json` connection. Set
`AIAGENT_SKIP_DB=oracle,pg` to skip unreachable backends.

## 12. Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `import yaspy` fails | driver not installed | `bash scripts/install_yaspy.sh` |
| `libyascli.so: cannot open shared object file` | `LD_LIBRARY_PATH` not set | `export LD_LIBRARY_PATH=~/.yashandb/client/lib:$LD_LIBRARY_PATH` |
| Server crashes with segfault | yaspy VECTOR GC bug | ensure `connection.py` converts `array.array` to string |
| `YAS-01017: invalid credentials` | wrong DB user/password | re-run `bash scripts/config_wizard.sh` |
| `crypto package not found` | missing grant | ask DBA to grant execute on the built-in crypto package |
| Server starts but `import oracledb` fails | wrong adapter - this is the YashanDB edition | use the Oracle release zip instead |
| Portal chat returns 500 | LLM `api_url` not configured | edit `config.json` -> `llm.api_url` |
| Deployment fails with "schema_version exists" | DB already has schema | drop schema or use `--force` |
| `config.json` has `_encrypted` but server can't decrypt | configured master key does not match | restore the matching `MASTER_DB_KEY` or `~/.ai-agent-infra/master.key` backup |
| yaspy `.so` symlinks broken after copy | zip cannot store symlinks | re-run `bash scripts/install_yaspy.sh` |

Server log: `viz_server.log` in the project directory.

## 14. v4.3.0 Integrated Graph Engineering and Governed Collaboration

This package uses the v4.3.0 shared code line. It includes the internal v4.2.1
Graph closure: versioned Graph Definitions, deterministic compilation, durable
Graph Runs, State Events, Checkpoints, Workers, Event Inbox/Outbox, Artifacts,
evaluators, reason-required interventions, a versioned Node Executor registry,
bounded delivery attempts, dead-letter replay, and operator governance events.
The internal v4.2.1 milestone is not a separately published package.

The migration tail above is part of the same profile and must be applied
through the checksum ledger before using the new Graph, Channel, Barrier, or
governance lifecycle objects.

YashanDB 23.5.4+ exposes the execution topology through its native Property
Graph projection. Relational `GRAPH_*` runtime tables remain the transaction
and recovery authority, and portable relational edge operations remain
available when a native graph query is not applicable.

Human and Agent activity is governed by the same Principal and database-backed
Session boundary. A permitted user creates a one-time Enrollment Token that
fixes sponsorship, owner, runtime, environment, risk tier, quota, and Security
Domain. A Channel is a collaboration view, not an authorization grant: it
cannot enlarge database, API, Skill, Tool, model, memory, Artifact, or export
access. Barrier arrivals and decisions are durable and attributable. The Agent
Gateway delivers channel events through short-lived instance tokens, fencing,
acknowledgement, retry, and dead-letter rules; web restart recovery is scoped to
the local node.

### Agent Skill Workflow

After registration and authentication, an external Agent can use the common
HTTP or MCP contract:

```bash
# Discover the native graph capability and registered types
curl -b cookies.txt http://localhost:<port>/api/graph/capabilities
curl -b cookies.txt http://localhost:<port>/api/graph-types

# Create a definition, create a Draft, compile, and publish
curl -b cookies.txt -H 'Content-Type: application/json' -d '{"name":"support-flow"}' \
  http://localhost:<port>/api/graphs
curl -b cookies.txt -H 'Content-Type: application/json' -d @graph-version.json \
  http://localhost:<port>/api/graphs/<graph_id>/versions
curl -b cookies.txt -H 'Content-Type: application/json' -d '{"reason":"validated POC topology"}' \
  http://localhost:<port>/api/graph-versions/<version_id>/compile
curl -b cookies.txt -H 'Content-Type: application/json' -d '{"reason":"approved for test execution"}' \
  http://localhost:<port>/api/graph-versions/<version_id>/publish
```

Workers receive bounded input and a short Lease Token, never Schema Owner
credentials. They must heartbeat, checkpoint, and complete/fail with the
fencing token; stale tokens cannot overwrite a newer Attempt. Use
`/api/graph-runs/<run_id>/state` and `/snapshot` to recover managed state after
a process restart. Existing Task Plan and Loop behavior remains available
through the v4.1 compatibility bridge.

### Executor and delivery operations

Executors are declarative manifests, not arbitrary Python, SQL, shell, or
network callbacks. Built-in `CONTROL`, `WORKER`, and `WAIT` Executors are
resolved for every node before claim and completion. Custom manifests require
an authenticated registration actor; disabling or deprecating one requires a
reason and affects new claims only.

```bash
curl -b cookies.txt 'http://localhost:<port>/api/graph-executors?include_inactive=true'
curl -b cookies.txt http://localhost:<port>/api/graph/events/inbox
curl -b cookies.txt http://localhost:<port>/api/graph/events/dead-letter
curl -b cookies.txt http://localhost:<port>/api/graph/events/outbox
curl -b cookies.txt -H 'Content-Type: application/json' \
  -d '{"reason":"verified downstream availability"}' \
  http://localhost:<port>/api/graph/events/inbox/<inbox_id>/replay
```

The database stores attempt counters, next-available time, maximum attempts,
and terminal `DEAD_LETTER` state. Non-idempotent external work is not blindly
replayed after an uncertain outcome.

The Graph contract may evolve within the v4.3.x maturity cycle. Breaking
changes require a new definition/schema version, migration or review state,
and new release evidence. The v4.3.1 production profile is the current
production baseline; v4.1.x remains available as the prior baseline.
Graduation is controlled by configuration and evidence, not a second code line.

## 13. Offline Deployment

The release zip contains the compiled Web runtime and the bundled dependency
set. The Web assets require no Node.js, npm, or network access. Python is
offline-installable only after `scripts/verify_deps.py` reports PASS; the
installer fails closed when a required wheel is absent or incompatible.
- `vendor/` - bundled Python wheels + yaspy native driver
- `vendor/yaspy/` - yaspy driver + YashanDB client libraries
- `scripts/install_yaspy.sh` - native driver install (recreates .so symlinks)
- `scripts/install_offline.sh` - installs remaining wheels
- `scripts/verify_deps.py` - integrity check
- `scripts/deploy_yashandb.py` - SQL deployment (auto-invokes install_yaspy.sh)
- `docs/deployment.md` - detailed deployment guide
