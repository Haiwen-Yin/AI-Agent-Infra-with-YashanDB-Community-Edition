# Release Notes - v3.10.2 (2026-07-17)

## Overview

**v3.10.2** introduces full support for YashanDB 23.5.4+ (崖山数据库) as the third supported database engine. Includes per-Agent independent crypto keys, config.json auto-encryption, key rotation API, offline deployment with yaspy driver, and Portal Markdown rendering.

## YashanDB Initial Adaptation

This release introduces full support for YashanDB 23.5.4+ (崖山数据库) as the third supported database engine.

### Supported YashanDB Features

| Feature | Status | Notes |
|---------|--------|-------|
| VECTOR type + HNSW Index | Native | VECTOR(n) + cosine_distance + FETCH APPROX |
| Property Graph | Native | CREATE PROPERTY GRAPH + GRAPH_TABLE |
| Full-text Search | Native | SEARCH INDEX + CONTAINS |
| JSON type | Native | Auto-conversion via yaspy driver |
| PL/SQL | Native | Packages, procedures, triggers |
| DBMS_SCHEDULER | Native | Scheduled jobs |
| LIST Partitioning | Native | Reference partitioning not supported |
| DBMS_CRYPTO | Partial | Named constants unavailable, numeric values used |
| Role-Based Access Control | Native | GRANT/REVOKE + DEFINER packages |

### YashanDB-Specific Adaptations

- **yaspy driver**: C extension .so file + client libraries (libyascli.so, libdrv_yashan.so)
- **Connection management**: Fresh connection per query (no connection pooling due to yaspy limitations)
- **VECTOR type workaround**: yaspy returns array.array for VECTOR columns, causing segfault during Python GC. Fixed in connection.py by immediate string conversion
- **JSON_OBJECT replacement**: YashanDB does not support JSON_OBJECT function. JSON generation handled in Python layer
- **JRD replacement**: JSON Relational Duality Views not supported. Regular views used instead
- **Reference partitioning**: Not supported. Regular tables used for child tables
- **systemd auto-restart**: Recommended due to occasional yaspy driver segfaults

### Test Results

| Edition | Tests | Pass Rate |
|---------|-------|-----------|
| YashanDB Community | 109 | 100% |
| YashanDB Enterprise | 113 | 100% |

## New Features

### Per-Agent Independent Crypto Keys

- Each Business Agent receives its own 256-bit encryption key at registration time
- Key stored in SYSTEM_CONFIG table (key = `agent_crypto_key:{agent_id}`)
- Distributed via admin_token-authenticated channel using `encrypt_credential_for_distribution()`
- Key version tracking via `agent_crypto_key_version:{agent_id}` for rotation detection

### Config.json Auto-Encryption on Startup

- `server.py` now calls `auto_encrypt_config()` on startup
- Encrypts `database` section (user, password, dsn)
- Encrypts `llm.api_key`
- Encrypts `model_routing.*_api_key` (simple/standard/complex)
- PBKDF2-HMAC-SHA512 key derivation + authenticated encryption with HMAC
- Master key stored in `~/.yashandb-infra/master.key` (chmod 600)

### Key Rotation API

- `POST /api/admin/crypto/rotate` - rotate keys for ALL active Agents
- `POST /api/admin/crypto/rotate/{agent_id}` - rotate key for a single Agent
- Automatic re-encryption of affected credentials with new key
- Agent heartbeat detects version change and triggers local re-encryption

### encrypt_config.py CLI Tool

- Commands: `encrypt`, `decrypt`, `rotate`, `verify`, `auto`
- Usage: `python3.14 -m tools.encrypt_config <command> [--config PATH]`

### Portal Chat Enhancements

- Markdown rendering for LLM responses (headers, code blocks, lists, bold/italic, links)
- Auto-scroll during streaming output
- Exit button clears session cookie and redirects to login
- Auto-detection of expired sessions
- `reasoning_effort: none` parameter for reasoning models (skip thinking process)

## Offline Deployment

- `vendor/` directory includes yaspy .so + YashanDB client libraries + 30 Python wheels
- `scripts/install_yaspy.sh` - installs yaspy driver and client libraries
- `scripts/install_offline.sh` - one-click offline installation
- `scripts/verify_deps.py` - dependency verification
- `scripts/deploy_yashandb.py` - pure Python deployment tool (state-machine SQL parser)

## Files Changed

- `scripts/lib/connection.py` - yaspy adapter (connection pool, CRUD, RETURNING INTO, VECTOR workaround)
- `scripts/lib/connection_crypto.py` - Per-Agent key functions, auto-encrypt, CLI tool
- `scripts/lib/config.py` - YashanDB database config, LLM/model_routing decryption
- `scripts/lib/agent_api.py` - Key generation, storage, rotation functions
- `scripts/visualization/server.py` - auto_encrypt_config(), crypto rotation endpoints, LLM streaming
- `scripts/tools/encrypt_config.py` - Config encryption CLI tool
- `scripts/deploy_yashandb.py` - YashanDB schema deployment tool
- `scripts/install_yaspy.sh` - yaspy driver installer
- `scripts/install_offline.sh` - Offline installation script
- `scripts/verify_deps.py` - Dependency verifier
- `scripts/visualization/templates/portal_chat.html` - Markdown, scroll, exit, session
- `scripts/visualization/templates/graph.html` - Simplified graph rendering
- `scripts/visualization/templates/monitor.html` - Sticky thead, filter badges
- `scripts/deploy/1_schema.sql` - Removed reference partitioning, JRD, inline FK constraints

## Upgrade Notes

- No schema changes from v3.10.1 (YashanDB uses same schema as Oracle with adaptations)
- After upgrading, run `bash scripts/install_offline.sh` to install yaspy + dependencies
- config.json will be auto-encrypted on first server startup
- Existing agents will have crypto keys generated on next heartbeat
- Use systemd with `Restart=always` for production deployments
