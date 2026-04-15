#!/usr/bin/env bash
# validate_env.sh — sourced by publish_pipeline.sh before the pipeline runs.
# Defines validate_config(); do NOT execute this script directly.

validate_config() {
    local errors=0

    _require_var() {
        local var="$1"
        if [[ -z "${!var:-}" ]]; then
            echo "[validate_config] ERROR: Required variable '$var' is not set." >&2
            errors=$((errors + 1))
        fi
    }

    _require_path() {
        local var="$1"
        local val="${!var:-}"
        if [[ -z "$val" ]]; then
            echo "[validate_config] ERROR: Required variable '$var' is not set." >&2
            errors=$((errors + 1))
        elif [[ ! -e "$val" ]]; then
            echo "[validate_config] ERROR: $var='$val' does not exist." >&2
            errors=$((errors + 1))
        fi
    }

    _require_var WORKING_DIR
    _require_var DEFAULT_BUILDER
    _require_var DEFAULT_STAGE
    _require_var GITHUB_REPO
    _require_var SIG_PASS
    _require_var CI_KEY
    _require_var INDEX_DIR
    _require_var INDEX_FILE
    _require_var PUB_KEY1
    # _require_var PUBLISH_BRANCH

    # Path existence checks (only if the var is actually set)
    [[ -n "${WORKING_DIR:-}" ]] && _require_path WORKING_DIR

    if [[ $errors -gt 0 ]]; then
        echo "[validate_config] $errors error(s) found. Check config.env and retry." >&2
        return 1
    fi

    echo "[validate_config] Config OK."
}
