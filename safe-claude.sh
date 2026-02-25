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

# Run Claude inside the container
exec docker run --rm -it \
    -v "$PWD:/workspace" \
    -v "$HOME/.claude:/home/node/.claude" \
    -v "$HOME/.claude.json:/home/node/.claude.json" \
    -w /workspace \
    "$IMAGE_NAME" \
    claude --dangerously-skip-permissions
