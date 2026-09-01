#!/usr/bin/env bash
#   usage: dependencies.sh [acacia|sddf]
#   With no argument, both projects are fetched.
set -euo pipefail

readonly SDDF_URL="https://github.com/au-ts/sddf.git"
readonly SDDF_BRANCH="sdfgenpy_split_serial"

readonly ACACIA_URL="https://github.com/au-ts/microkit_acacia.git"
readonly ACACIA_BRANCH="main"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
    printf 'usage: %s [acacia|sddf]\n' "$(basename "$0")" >&2
    exit 1
}

fetch() {
    local url="$1" branch="$2" dest="$3"

    if [ -e "$dest" ]; then
        printf '%s already exists, skipping\n' "$dest"
        return 0
    fi

    printf '%s (branch: %s) -> %s\n' "$url" "$branch" "$dest"

    if command -v git >/dev/null 2>&1; then
        git clone --quiet --depth 1 --branch "$branch" "$url" "$dest"
        rm -rf "$dest/.git"
    else
        printf 'error: no git!\n' >&2
        exit 1
    fi
}

[ $# -le 1 ] || usage
target="${1:-all}"

case "$target" in
    acacia|sddf|all) ;;
    *) usage ;;
esac

cd "$SCRIPT_DIR"

case "$target" in
    sddf)   fetch "$SDDF_URL"   "$SDDF_BRANCH"   "sddf" ;;
    acacia) fetch "$ACACIA_URL" "$ACACIA_BRANCH" "acacia" ;;
    all)
        fetch "$SDDF_URL"   "$SDDF_BRANCH"   "sddf"
        fetch "$ACACIA_URL" "$ACACIA_BRANCH" "acacia"
        ;;
esac
printf 'done\n'
