# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Strict Boundary Rule

**File operations are allowed within the `frprep/` directory tree ONLY.** This includes:
- `C:\PCFolders\Main\Learning\Docker\frprep\fr\sndbx1\` (current repo)
- `C:\PCFolders\Main\Learning\Docker\frprep\fr\` (parent)
- `C:\PCFolders\Main\Learning\Docker\frprep\` (all contents)
- Any sibling directories under `frprep/` (e.g., `frprep/frnotes/`)

**STRICTLY FORBIDDEN:** Never access anything above `frprep/` (e.g., `C:\PCFolders\Main\Learning\Docker\`, `C:\PCFolders\`, or any other locations outside the `frprep/` tree). If a task requires files outside this boundary, stop and ask the user for guidance instead of proceeding.

## Session Startup

**At the start of every new session, read `../../frnotes/LAB_TRACKER.md` first.** This file tracks lab progression and current status. Review it before doing any work to understand where the user left off.

**As labs are completed or progress is made, update `../../frnotes/LAB_TRACKER.md`** to reflect the current status. Keep it accurate so future sessions have an up-to-date picture of what has been done and what remains.

**Update the topic-specific interview Q&A files in `../../frnotes/`** (e.g., `INT_QA_IDM_Install.md`, `INT_QA_Policies.md`, `INTERVIEW_QUESTIONS.md`) as new concepts are learned or debugged during labs. Add new questions and answers that reflect practical insights gained from hands-on work.

## Interview Q&A File Rules

- **Maximum 15 questions per file.** If a topic's `INT_QA_<topic>.md` file already has 15 questions, create a numbered sequel: `INT_QA_<topic>_2.md`, `INT_QA_<topic>_3.md`, etc.
- **Every Q&A file must have an Index table at the top** listing question number, question text, and topic/tag. This makes files scannable.
- **Keep answers concise.** Break large concepts into multiple focused questions rather than one long answer.
- **Existing files are grandfathered.** Do not split or renumber files that already exceed 15 questions. The rule applies to new questions going forward.
- **Update `INT_QA_INDEX.md`** whenever a new Q&A file or sequel is created.

## Docker CLI

Always use `docker.exe` (not `docker`) when running Docker commands. For example: `docker.exe compose`, `docker.exe logs`, `docker.exe exec`, `docker.exe build`, etc.

## Container and Compose Safety

- **Do NOT automatically start or stop containers** at session startup or at any point without explicit user request.
- **Before starting, stopping, or restarting any container**, always inform the user and wait for confirmation.
- **Before editing any existing `docker-compose*.yaml` file**, always explain the proposed changes and get explicit approval first.
- It is fine to _read_ compose files and check container status (`docker.exe ps`) without asking.
- **Exception — auto-update allowed**: `CLAUDE.md` and `../../frnotes/LAB_TRACKER.md` may be edited freely without asking. Keep them up to date as work progresses.

## Hands-On Learning Approach

This is a learning environment. **Do NOT automatically perform configurations via curl or REST calls.** Instead, debug, research, and identify what needs to be configured, then provide the user with clear step-by-step instructions to do it themselves (e.g., via AM Console, IDM Admin UI, or manual curl commands the user runs). The user learns by doing. Use curl/REST only for read-only queries (checking status, verifying results) or when the user explicitly asks to automate something.

## Current Focus: IDM Lead Engineer Interview Preparation

**As of Session 18 (2026-02-06):** The user is preparing for a **ForgeRock/Ping IDM Lead Engineer** role (7-8 years experience). We are systematically working through the IDM curriculum defined in `../../frnotes/idm/IDM_CURRICULUM.md`.

**Progress Tracking:**
- Full curriculum progress tracked in `../../frnotes/LAB_TRACKER.md` (see "IDM Lead Engineer Curriculum Progress" section)
- Interview Q&A files stored in `../../frnotes/idm/INT_QA_IDM_*.md` (15 questions max per file)
- Current topic: Topic 1 - IDM Architecture & Fundamentals (✅ Completed)
- Next topic: Topic 2 - Connector Development & Configuration

**Session Startup for IDM Work:**
1. Read `../../frnotes/LAB_TRACKER.md` to see current curriculum progress
2. Check which topic is in progress
3. Continue building interview Q&A notes at Lead Engineer depth
4. Update LAB_TRACKER.md as topics are completed

**IDM Environment Status:**
- `pingidm` container running on port 8082 (http://localhost:8082)
- `pingds-idm` container running on ports 2389 (LDAP), 2636 (LDAPS), 5444 (admin)
- Managed users and link table populated from previous session
- LDAP connector configured to sync with AM's DS (pingds:1636)

## Project Overview

ForgeRock/Ping Identity IAM sandbox lab environment running on Docker. Deploys PingDS (Directory Server), PingAM (Access Manager), and optionally PingIDM (Identity Management) with supporting services.

## Build and Run Commands

```bash
# Create the external network (required once)
docker.exe network create fr-net

# Build and start core services (PingDS + PingAM)
docker.exe compose build
docker.exe compose up -d

# Optional: Add IDM services
docker.exe compose -f docker-compose.idm.yaml build
docker.exe compose -f docker-compose.idm.yaml up -d

# Optional: Add email testing
docker.exe compose -f docker-compose.mailpit.yaml up -d

# Optional: Add PingGateway + sample app
docker.exe compose -f docker-compose.gw.yaml build
docker.exe compose -f docker-compose.gw.yaml up -d

# View logs
docker.exe logs -f pingds
docker.exe logs -f pingam

# Tear down
docker.exe compose down
docker.exe compose -f docker-compose.idm.yaml down
```

## Prerequisites

Software installers must be placed manually before building:
- `pingds/software/` — DS zip (e.g., `DS-8.0.zip`)
- `pingam/software/` — AM war (e.g., `AM-8.0.2.war`)
- `pingidm/software/` — IDM zip (e.g., `IDM-8.0.1.zip`) (if using IDM)

## Architecture

### Service Dependency Chain

PingDS starts first and sets up three AM data stores (am-config, am-identity-store, am-cts). After the DS server is healthy, a background process exports certificates to a shared Docker volume. PingAM waits for PingDS health, then polls for the truststore (up to 180s), imports it into Tomcat's keystore, and starts.

### Docker Compose Files

- `docker-compose.yaml` — Core stack: PingDS + PingAM on `fr-net` external network
- `docker-compose.idm.yaml` — Adds PingDS-IDM (dedicated DS for IDM) + PingIDM
- `docker-compose.mailpit.yaml` — Adds Mailpit email service for testing
- `docker-compose.gw.yaml` — Adds PingGateway + sample application on `fr-net`

### Certificate Flow

1. `setup-ds.sh` generates a deployment ID, saved to `${DATA_DIR}/.deployment_id`
2. `export-certificates.sh` (runs post-startup) reads that ID and exports CA cert + PKCS12 truststore to `/opt/certs/` (shared volume)
3. PingAM's entrypoint copies the truststore into Tomcat's keystores directory

### Port Mappings

| Service | HTTP | LDAP | LDAPS | Admin |
|---------|------|------|-------|-------|
| PingDS | 8080 | 1389 | 1636 | 4444 |
| PingAM | 8081 | — | — | 8444 (HTTPS) |
| PingDS-IDM | — | 2389 | 2636 | 5444 |
| PingIDM | 8082 | — | — | — |
| PingGateway | 8083 | — | — | 9083 (admin) |
| Sample App | 8084 | — | — | — |
| Mailpit | 8025 | — | — | 1025 (SMTP) |

### Access URLs

- PingAM: `http://localhost:8081/am`
- PingIDM: `http://localhost:8082`
- PingGateway: `http://localhost:8083`
- PingGateway Admin: `http://localhost:9083/openig/api/info`
- Sample App: `http://localhost:8084`
- Mailpit: `http://localhost:8025`

### Container Users

- `pingds` — UID 1000 (entrypoint runs as root initially for volume permissions, then drops via `gosu`)
- `tomcat` — UID 1001
- `openidm` — UID 11111

### Key Environment Defaults

All default passwords are `Passw0rd123`. Truststore password is `changeit`.

## Key Files

- `pingds/scripts/setup-ds.sh` — DS initialization with AM profiles
- `pingds/scripts/docker-entrypoint.sh` — DS startup, permission handling, certificate export trigger
- `pingds/scripts/export-certificates.sh` — Certificate export to shared volume
- `pingam/scripts/docker-entrypoint.sh` — Truststore import and Tomcat startup
- `pingam/Dockerfile` — Based on `tomcat:10-jdk21`, deploys `am.war` to `/am` context
- `pingds/Dockerfile` — Based on `eclipse-temurin:21-jre-jammy`

## Conventions

- All entrypoint scripts are bash and must be executable
- Startup scripts are idempotent (check for existing state before running setup)
- All services share the `fr-net` external Docker network
- Certificate sharing between containers uses named Docker volumes
- JVM settings: G1GC, heap sizes configured per service (DS: 1g, AM: 1g-2g, IDM-DS: 512m)
