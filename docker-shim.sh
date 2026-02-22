#!/bin/bash
# Shim that wraps podman as docker, stripping flags podman doesn't support
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --provenance*) ;;
    *) ARGS+=("$arg") ;;
  esac
done
exec /opt/homebrew/bin/podman "${ARGS[@]}"
