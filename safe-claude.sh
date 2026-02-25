#!/usr/bin/env bash
set -euo pipefail

# Resolve the directory containing this script (follows symlinks)
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

IMAGE_NAME="safe-claude:latest"
REBUILD=false

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --rebuild)
            REBUILD=true
            ;;
        --help|-h)
            echo "Usage: safe-claude [--rebuild]"
            echo ""
            echo "Runs Claude Code with --dangerously-skip-permissions inside a Docker container."
            echo "The current directory is mounted as /workspace inside the container."
            echo ""
            echo "Flags:"
            echo "  --rebuild   Force a fresh Docker image build"
            exit 0
            ;;
    esac
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
CLAUDE_JSON_TMP=$(mktemp /tmp/claude-json-XXXXXX.json)
cp "$HOME/.claude.json" "$CLAUDE_JSON_TMP"
cleanup() { rm -f "$CLAUDE_JSON_TMP"; }
trap cleanup EXIT

# Run Claude inside the container
docker run --rm -it \
    -v "$PWD:/workspace" \
    -v "$HOME/.claude:/home/node/.claude" \
    -v "$CLAUDE_JSON_TMP:/home/node/.claude.json" \
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
