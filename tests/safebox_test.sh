#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/safebox-test-XXXXXX")"
TEST_HOME="$TEST_TMP/home"
MOCK_BIN="$TEST_TMP/bin"
PROJECT_DIR="$TEST_TMP/project"

cleanup() {
    rm -rf "$TEST_TMP"
}
trap cleanup EXIT

mkdir -p "$TEST_HOME" "$MOCK_BIN" "$PROJECT_DIR"

cat > "$MOCK_BIN/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >> "$DOCKER_ARGS_LOG"
printf '%s\n' '---' >> "$DOCKER_ARGS_LOG"
EOF
chmod +x "$MOCK_BIN/docker"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

run_safebox() {
    local log_file="$1"
    shift
    : > "$log_file"
    (
        cd "$PROJECT_DIR"
        HOME="$TEST_HOME" \
        PATH="$MOCK_BIN:$PATH" \
        DOCKER_ARGS_LOG="$log_file" \
        GH_TOKEN= GITHUB_TOKEN= GH_USER= \
        ANTHROPIC_API_KEY= OPENAI_API_KEY= GOOGLE_API_KEY= GEMINI_API_KEY= \
        GROQ_API_KEY= MISTRAL_API_KEY= AZURE_OPENAI_API_KEY= \
        AWS_BEDROCK_API_KEY= DEEPSEEK_API_KEY= \
            "$ROOT_DIR/safebox" claude "$@"
    ) >/dev/null 2>&1
}

assert_host_network_enabled() {
    local log_file="$1"
    awk '
        $0 == "---" { in_run = 0; previous = ""; next }
        !in_run && $0 == "run" { in_run = 1; next }
        in_run && previous == "--network" && $0 == "host" { found = 1 }
        in_run { previous = $0 }
        END { exit(found ? 0 : 1) }
    ' "$log_file" || fail "docker run did not receive --network host"
}

HOST_NETWORK_LOG="$TEST_TMP/host-network.log"
run_safebox "$HOST_NETWORK_LOG" --allow-host-network
assert_host_network_enabled "$HOST_NETWORK_LOG"

DEFAULT_LOG="$TEST_TMP/default.log"
run_safebox "$DEFAULT_LOG"
if grep -qx -- '--network' "$DEFAULT_LOG"; then
    fail "docker run received a network override by default"
fi

HELP_OUTPUT="$TEST_TMP/help.txt"
"$ROOT_DIR/safebox" --help > "$HELP_OUTPUT"
grep -q -- '--allow-host-network' "$HELP_OUTPUT" \
    || fail "help output does not document --allow-host-network"

echo "PASS: safebox host-network flag"
