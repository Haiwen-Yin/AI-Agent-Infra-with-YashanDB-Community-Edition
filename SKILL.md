# SKILL.md - AI Agent Infra with YashanDB

> **Version:** 4.1.0 | **Driver:** yaspy 1.2.1 | **DB:** YashanDB 23.5.4+ (崖山数据库)

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

v4.1.0 requires every external or platform-hosted Agent to register and
authenticate before using non-bootstrap APIs. The Enterprise resource catalog
is authoritative for classification; unknown or sensitive resources without an
explicit policy are denied. Approval, emergency, audit, retention, legal-hold,
and evidence-export controls are enforced by the server and database rather
than by Dashboard visibility.

## 2. Package Contents

After extracting the release zip, you have:

```
AI-Agent-Infra-with-YashanDB-{Community,Enterprise}-Edition/
├── SKILL.md                        # this file
├── CHANGELOG.md                    # full version history
├── RELEASE_NOTES_v4.1.0.md   # this release's notes
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
├── vendor/                         # 29 pre-downloaded wheels + yaspy native libs (offline)
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
    │   ├── 8_v4_1_0_registration.sql # registered-Agent boundary
    │   └── 8_v4_1_0_governance.sql   # Enterprise governance objects
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

## 4. Installation (offline-friendly)

The release zip is self-contained - no PyPI access needed. **Two install
steps are required** (in this order):

```bash
# 1. Extract the zip
unzip AI-Agent-Infra-with-YashanDB-Enterprise-Edition-v4.1.0.zip
cd AI-Agent-Infra-with-YashanDB-Enterprise-Edition

# 2. Install yaspy driver + YashanDB client libraries (REQUIRED FIRST)
bash scripts/install_yaspy.sh
# -> copies yaspy.cpython-*.so to Python site-packages
# -> copies client_lib/*.so.1.4.100 to ~/.yashandb/client/lib/
# -> recreates the .so and .so.MAJOR symlinks (cannot survive zip archive)
# -> exports LD_LIBRARY_PATH in ~/.bashrc

# 3. Install remaining Python dependencies from vendor/
bash scripts/install_offline.sh

# 4. Verify all dependencies are present
python3 scripts/verify_deps.py
```

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
python3 scripts/tools/encrypt_config.py encrypt config.json
python3 scripts/tools/encrypt_config.py decrypt config.json
```

## 6. Database Schema Deployment

The release includes `scripts/deploy_yashandb.py` - a pure-Python SQL
deployment tool. It runs the SQL scripts in `scripts/deploy/` in order,
and automatically invokes `install_yaspy.sh` first if needed.

```bash
# Deploy schema + API packages + jobs + grants (Enterprise)
python3 scripts/deploy_yashandb.py <user> <password> <host>:1688/<service> \
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
python3 scripts/agent_bootstrap.py register \
    --agent-id MY_AGENT \
    --agent-name "My Business Agent" \
    --admin-token AT_xxx \
    --admin-url http://<admin-host>:<port>

# Test the resulting connection
python3 scripts/agent_bootstrap.py test

# Recover if the agent crashed and lost credentials
python3 scripts/agent_bootstrap.py recover \
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
python3 -m pytest scripts/tests/ -v

# Or the legacy runner
cd scripts && python -m tests.test_all
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

## 13. Offline Deployment

The release zip is fully self-contained:
- `vendor/` - 29 wheels + yaspy native driver (no PyPI access needed)
- `vendor/yaspy/` - yaspy driver + YashanDB client libraries
- `scripts/install_yaspy.sh` - native driver install (recreates .so symlinks)
- `scripts/install_offline.sh` - installs remaining wheels
- `scripts/verify_deps.py` - integrity check
- `scripts/deploy_yashandb.py` - SQL deployment (auto-invokes install_yaspy.sh)
- `docs/deployment.md` - detailed deployment guide
