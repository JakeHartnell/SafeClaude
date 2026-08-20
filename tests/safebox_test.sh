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
    local harness="$2"
    local output_file="$TEST_TMP/safebox-$harness.out"
    shift 2
    : > "$log_file"
    if ! (
        cd "$PROJECT_DIR"
        HOME="$TEST_HOME" \
        PATH="$MOCK_BIN:$PATH" \
        DOCKER_ARGS_LOG="$log_file" \
        GH_TOKEN= GITHUB_TOKEN= GH_USER= \
        ANTHROPIC_API_KEY= OPENAI_API_KEY= XAI_API_KEY="${TEST_XAI_API_KEY:-}" \
        GOOGLE_API_KEY= GEMINI_API_KEY= \
        GROQ_API_KEY= MISTRAL_API_KEY= AZURE_OPENAI_API_KEY= \
        AWS_BEDROCK_API_KEY= DEEPSEEK_API_KEY= \
            "$ROOT_DIR/safebox" "$harness" "$@"
    ) >"$output_file" 2>&1; then
        sed -n '1,160p' "$output_file" >&2
        fail "safebox $harness invocation failed"
    fi
}

assert_run_pair() {
    local log_file="$1" first="$2" second="$3" description="$4"
    awk -v first="$first" -v second="$second" '
        $0 == "---" { in_run = 0; previous = ""; next }
        !in_run && $0 == "run" { in_run = 1; next }
        in_run && previous == first && $0 == second { found = 1 }
        in_run { previous = $0 }
        END { exit(found ? 0 : 1) }
    ' "$log_file" || fail "docker run did not receive $description"
}

HOST_NETWORK_LOG="$TEST_TMP/host-network.log"
run_safebox "$HOST_NETWORK_LOG" claude --allow-host-network
assert_run_pair "$HOST_NETWORK_LOG" --network host "--network host"

DEFAULT_LOG="$TEST_TMP/default.log"
run_safebox "$DEFAULT_LOG" claude
if grep -qx -- '--network' "$DEFAULT_LOG"; then
    fail "docker run received a network override by default"
fi

GROK_LOG="$TEST_TMP/grok.log"
TEST_XAI_API_KEY=xai-test-key \
    run_safebox "$GROK_LOG" grok -- --model grok-build
assert_run_pair "$GROK_LOG" -v \
    "$TEST_HOME/.grok:/home/node/.grok" "the Grok config mount"
assert_run_pair "$GROK_LOG" -e "XAI_API_KEY=xai-test-key" "XAI_API_KEY"
assert_run_pair "$GROK_LOG" grok --always-approve \
    "the Grok always-approve launch command"
assert_run_pair "$GROK_LOG" --always-approve --no-auto-update \
    "the Grok auto-update override"
assert_run_pair "$GROK_LOG" --no-auto-update --model \
    "Grok passthrough arguments"

HELP_OUTPUT="$TEST_TMP/help.txt"
"$ROOT_DIR/safebox" --help > "$HELP_OUTPUT"
grep -q -- '--allow-host-network' "$HELP_OUTPUT" \
    || fail "help output does not document --allow-host-network"
grep -q -- '^  grok ' "$HELP_OUTPUT" \
    || fail "help output does not list the Grok harness"

echo "PASS: safebox host-network and Grok harness wiring"
