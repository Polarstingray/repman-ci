# Repman-CI Codebase Audit

Audit performed for Stingray ticket **#77 — Repman-CI Codebase Audit**. The goal
was to read the codebase end to end, identify issues and high-value refactoring
opportunities, and file actionable Task tickets for the resolver bots to
implement (routed by difficulty).

## Scope reviewed

- `main.py` — CLI entrypoint, argument parsing, subprocess orchestration.
- `core/index.py`, `core/stage.py`, `core/keygen.py` — metadata index, versioning,
  staging, and config-file editing.
- `scripts/*.sh` — the publish pipeline and its per-step scripts.
- `builders/` — Docker builder compose files and `build_images.sh`.
- `data/config.env.example`, `README.md`, and the `tests/` suite.

Baseline: the existing suite passes — **59 unit tests green** via
`./tests/run_tests.sh --unit-only`.

## Findings → filed tickets

Tickets are tiered by difficulty and assigned per the parent ticket: hardest to
the Claude bot, medium to the open bot, easiest to the Gemini bot. Each sub-ticket
body instructs the implementing resolver to reassign to the admin once done.

| Ticket | Difficulty | Assignee | Summary |
|--------|-----------|----------|---------|
| **#78** | hard | Claude (id 2) | The ~13-line config-bootstrap header (resolve `SCRIPT_DIR`, detect `lib/` install layout, source user/`data` `config.env`, pin+export `WORKING_DIR`) is copy-pasted verbatim across all 8 `scripts/*.sh`. Extract it into one sourced `scripts/bootstrap.sh`. |
| **#79** | hard | Claude (id 2) | Versioning bugs in `core/stage.py`/`core/index.py`: (1) building an existing package for a *new* `os_arch` resets the version to `1.0.0` because `get_version` is per-target and returns `None`; (2) `add_version`'s "already exists" no-op is reported as success, so the pipeline builds/signs/publishes a duplicate. |
| **#80** | medium | open (id 4) | The single-target dict `{url, signature, sha256}` is hand-built in three places in `core/index.py` (and the `notes` block twice). Extract a `_make_target_entry()` helper. |
| **#81** | medium | open (id 4) | `<os>_<arch>` parsing is duplicated: `main.py._parse_builder` validates, `core/stage.py.parse_builder` does an unguarded `split("_")` that crashes opaquely. Consolidate into one validated helper. |
| **#82** | low | Gemini (id 3) | `README.md` is stale: references `package_and_sign.sh` (actual: `package_sign.sh`), attributes index logic to `stage.py` instead of `index.py`, documents a root `.env`/`DEFAULT_BUILDER=ubuntu` instead of `data/config.env` + `ubuntu_amd64`, and calls the index "Wyse index" while the code calls it the metadata index. |

## Other observations (not ticketed)

These are lower-value or design-judgment items noted during the read, left
un-ticketed to keep the actionable queue focused:

- `greater_version()` assumes a strict `X.Y.Z` numeric form and will raise on any
  pre-release / non-numeric version — relevant if the "Index versioning" /
  "Pre-release channels" future work in the README is pursued.
- `stage_artifacts.sh` `mkdir -p`s the `signatures` and `index` staging dirs but
  not `keys/` before `rsync`-ing the public key into it (works today only because
  `rsync` creates the single final component).
- `publish_github.sh`'s `_on_failure` ERR trap references `$TAG`, which is unset
  under `set -u` if a failure occurs before `TAG` is assigned.
- `cmd_get_builders` (prints full `*-builder.yml` filenames) and
  `_resolve_builders("all")` (strips the suffix to bare names) use divergent
  listing logic for the same directory.
