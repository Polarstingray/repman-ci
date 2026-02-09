# Repman Package Pipeline

Repman package pipeline is a **lightweight, artifact‑first package publishing and update system** designed for personal projects and homelab environments.

It provides:

* Reproducible builds via Docker
* Signed, immutable release artifacts
* GitHub Releases as the distribution backend
* A simple, extensible metadata and index model

This project intentionally avoids heavyweight tooling (Deb/RPM repos, full CI SaaS) in favor of **transparent, inspectable scripts**.

---

## High‑Level Architecture

```
source project
   │
   ▼
[ Docker Builder ]  ← reproducible build environment
   │
   ▼
Signed Artifact (.tar.gz)
   │
   ▼
GitHub Release (tagged)
   │
   ▼
Server Index  →  Repman package manager (Client, update / install)
```

**Key principle:**

> The artifact is the unit of truth. Everything else derives from it.

---

## Artifact Model

Each release produces **exactly one canonical artifact** per platform:

```
<name>-v<version>-<os>-<arch>.tar.gz
```

The artifact contains:

* Compiled binaries
* Runtime assets
* `metadata.json`

Alongside the artifact:

* Minisign signature (`.minisig`)
* SHA256 checksum (`.sha256`)

Only these signed blobs are published.

---

## Repository Layout

```
ci_runner/
├── builders/            # Docker builder definitions
│   └── ubuntu-builder.yml
├── core/
│   └── stage.py         # Metadata + index logic
├── scripts/             # Pipeline scripts
│   ├── publish_pipeline.sh
│   ├── prepare_stage.sh
│   ├── build_artifact.sh
│   ├── generate_metadata.sh
│   ├── package_and_sign.sh
│   ├── stage_artifacts.sh
│   └── publish_github.sh
├── src/                 # Staged project source (ephemeral)
├── out/                 # Build outputs (ephemeral)
├── .env                 # Configuration
└── README.md
```

---

## Pipeline Overview

The pipeline is split into **small, focused scripts** orchestrated by a single entrypoint.

### Orchestrator

```
publish_pipeline.sh
```

This is the **only script you normally run**.

It coordinates:

1. Workspace preparation
2. Containerized build
3. Metadata generation
4. Artifact packaging and signing
5. Staging
6. GitHub release publishing

---

## Usage

### 1. Project Requirements

Each project must include a `setup.sh` at its root.

Minimal example:

```bash
#!/usr/bin/env bash
set -e

make
mkdir -p out/bin
cp my_binary out/bin/
```

The build must place outputs under `out/`.

---

### 2. Environment Configuration

Create `.env`:

```env
WORKING_DIR=/srv/docker/ci_runner
DEFAULT_STAGE=/srv/packages
DEFAULT_BUILDER=ubuntu
SIG_PASS=your_minisign_password
```

Ensure:

* `docker` and `docker-compose`
* `gh` (GitHub CLI)
* `minisign`
* `jq`

---

### 3. Publishing a Project

```bash
./publish_pipeline.sh <project_path> <update_type> [builder] [staging_dir]
```

Example:

```bash
./publish_pipeline.sh ~/projects/affirm minor ubuntu
```

This will:

* Build the project in Docker
* Generate versioned metadata
* Create a signed artifact
* Publish a GitHub Release

---

## GitHub Releases

Each release corresponds to:

* An **annotated git tag**
* A **GitHub Release**
* Uploaded assets:

  * `.tar.gz`
  * `.minisig`
  * `.sha256`

Tag format:

```
<name>-v<version>
```

Example:

```
affirm-v1.2.0
```

GitHub is used **only as a blob store and index**, not as a build system.

---

## Wyse Index

The Wyse index tracks the latest trusted releases.

Example:

```json
{
    "affirm": {
        "latest": "1.0.5",
        "versions": {
            "1.0.5": {
                "targets": {
                    "ubuntu_amd64": {
                        "url": "https://github.com/Polarstingray/packages/affirm_v1.0.5_ubuntu_amd64",
                        "signature": "affirm_v1.0.5_ubuntu_amd64.tar.gz.minisig",
                        "sha256": "affirm_v1.0.5_ubuntu_amd64.tar.gz.sha256"
                    }
                }
            },
        }
    }
}
```

Clients:

1. Fetch index
2. Download artifact
3. Verify signature + hash
4. Extract and install

---

## Security Model

* **Minisign** provides authenticity
* **SHA256** provides integrity
* GitHub tags provide immutability

Unsigned or unpackaged files are never trusted.

---

## Design Philosophy

* Artifact‑first
* Immutable releases
* Minimal abstraction
* No hidden state
* Easy to audit

This system intentionally mirrors how real package ecosystems work internally, without their operational overhead.

---

## Future Work

Planned or optional enhancements:

* Repman client (`repman install / update`)
* Multi‑architecture builds
* Pre‑release channels
* Index versioning
* Automated changelogs

---

## Status

Undergrad student at the University of Minnesota

---

## Final Note

repman pk/pi is not meant to replace system package managers.

It is a **personal distribution pipeline** for projects you control, trust, and publish yourself.
