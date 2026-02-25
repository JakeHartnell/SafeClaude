#!/usr/bin/env bash
set -euo pipefail

# Resolve the directory containing this script (follows symlinks)
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

IMAGE_NAME="safe-claude:latest"
REBUILD=false
EXTRA_MOUNTS=()

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --rebuild)
            REBUILD=true
            shift
            ;;
        --mount)
            if [[ $# -lt 2 ]]; then
                echo "safe-claude: --mount requires an argument" >&2
                exit 1
            fi
            EXTRA_MOUNTS+=("$2")
            shift 2
            ;;
        --mount=*)
            EXTRA_MOUNTS+=("${1#--mount=}")
            shift
            ;;
        --help|-h)
            echo "Usage: safe-claude [--rebuild] [--mount SRC[:DEST]] ..."
            echo ""
            echo "Runs Claude Code with --dangerously-skip-permissions inside a Docker container."
            echo "The current directory is mounted as /workspace inside the container."
            echo ""
            echo "Flags:"
            echo "  --rebuild            Force a fresh Docker image build"
            echo "  --mount SRC[:DEST]   Mount an extra host path into the container."
            echo "                       If DEST is omitted, SRC is used as the destination."
            echo "                       May be repeated for multiple mounts."
            exit 0
            ;;
        *)
            echo "safe-claude: unknown option: $1" >&2
            echo "Run 'safe-claude --help' for usage." >&2
            exit 1
            ;;
    esac
done

# Validate and build extra mount flags
EXTRA_MOUNT_FLAGS=()
for spec in "${EXTRA_MOUNTS[@]+"${EXTRA_MOUNTS[@]}"}"; do
    if [[ "$spec" == *:* ]]; then
        src="${spec%%:*}"
        dest="${spec#*:}"
    else
        src="$spec"
        dest="$spec"
    fi

    if [[ -z "$src" ]]; then
        echo "safe-claude: malformed mount spec (empty src): $spec" >&2
        exit 1
    fi
    if [[ ! -e "$src" ]]; then
        echo "safe-claude: mount source does not exist: $src" >&2
        exit 1
    fi

    src="$(readlink -f "$src")"

    # Default dest to /mnt/<basename> when not specified
    if [[ -z "$dest" ]]; then
        dest="/mnt/$(basename "$src")"
    fi

    # Skip if already mounted by default
    if [[ "$src" == "$PWD" ]]; then
        echo "safe-claude: --mount $spec: already mounted as /workspace, skipping" >&2
        continue
    fi
    if [[ "$src" == "$(readlink -f "$HOME/.claude")" ]]; then
        echo "safe-claude: --mount $spec: ~/.claude already mounted, skipping" >&2
        continue
    fi

    EXTRA_MOUNT_FLAGS+=(-v "$src:$dest")
done

# Build image if it doesn't exist or --rebuild was requested
if $REBUILD || ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
    echo "Building $IMAGE_NAME..."
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
fi

# Ensure host-side credential targets exist so Docker bind-mounts them as
# files/dirs rather than creating empty directories in their place.
mkdir -p "$HOME/.claude"
touch "$HOME/.claude.json"

# Copy .claude.json to a temp file so the container never writes directly to
# the host file (Docker's macOS filesystem layer can corrupt atomic renames).
CLAUDE_JSON_TMP=$(mktemp /tmp/claude-json-XXXXXX)
cp "$HOME/.claude.json" "$CLAUDE_JSON_TMP"
cleanup() { rm -f "$CLAUDE_JSON_TMP"; }
trap cleanup EXIT

# Run Claude inside the container
docker run --rm -it \
    -v "$PWD:/workspace" \
    -v "$HOME/.claude:/home/node/.claude" \
    -v "$CLAUDE_JSON_TMP:/home/node/.claude.json" \
    "${EXTRA_MOUNT_FLAGS[@]+"${EXTRA_MOUNT_FLAGS[@]}"}" \
    -w /workspace \
    "$IMAGE_NAME" \
    claude --dangerously-skip-permissions
EXIT_CODE=$?

# Copy the temp file back only if it is valid JSON (preserves auth/setting
# updates while protecting the host file if the container corrupted it).
if jq empty "$CLAUDE_JSON_TMP" 2>/dev/null; then
    cp "$CLAUDE_JSON_TMP" "$HOME/.claude.json"
else
    echo "safe-claude: container wrote invalid JSON to .claude.json — host file left unchanged." >&2
fi

exit $EXIT_CODE
