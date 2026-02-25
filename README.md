# Safe Claude

A self-contained toolkit for running Claude Code with `--dangerously-skip-permissions` safely inside a Docker container. Copy or clone this directory anywhere and get a one-command sandboxed Claude session from any project.

## What is this

Claude Code's `--dangerously-skip-permissions` flag is powerful — it lets Claude run shell commands, edit files, and install packages without prompting for approval on every action. That power is risky on your host machine. `safe_claude` wraps Claude in a Docker container so those actions happen in an isolated environment: your project files are visible (via a mount), but the container can't touch the rest of your system.

## Quick start

```bash
# 1. Clone or copy this directory somewhere convenient
git clone <repo> && cp -r <repo>/safe_claude ~/safe_claude

# 2. Set your API key
export ANTHROPIC_API_KEY=sk-ant-...

# 3. Run from any project directory
cd ~/my-project
~/safe_claude/safe-claude.sh
```

The first run builds the Docker image automatically. Subsequent runs start in seconds.

---

## Daily usage

The easiest workflow is a symlink so you can call `safe-claude` from anywhere:

```bash
ln -s ~/safe_claude/safe-claude.sh ~/bin/safe-claude
# (ensure ~/bin is in your PATH)
```

Then from any project:

```bash
cd /any/project
safe-claude
```

Claude opens with `/any/project` mounted as `/workspace` inside the container. Your `~/.claude` directory is also mounted so memory and configuration persist across sessions.

---

## Flags

| Flag | Description |
|------|-------------|
| `--rebuild` | Force a fresh Docker image build (useful after editing the Dockerfile) |
| `--help` | Show usage information |

---

## Safety model

### What IS sandboxed

- The host filesystem outside `$PWD` — Claude can only see your current project directory
- System binaries and configuration — the container has its own isolated OS
- Other users' files and processes

### What is NOT sandboxed

- **Network access** — the container has full outbound internet access. Claude can `curl`, `npm install`, `git clone`, etc. This is intentional (many legitimate tasks need it) but worth being aware of.
- **Your project files** — `$PWD` is mounted read-write so Claude can edit your code. That's the point, but it means changes are real and immediate.
- **`~/.claude`** — your Claude config and memory are mounted so sessions persist. Be aware that Claude can read and write this directory.

If you need network isolation too, add `--network none` to the `docker run` call in `safe-claude.sh` (note: this will break package installs and API calls that require outbound connectivity).

---

## Customisation

Edit `Dockerfile` to add tools or change the base image, then rebuild:

```bash
# Edit the Dockerfile
vim ~/safe_claude/Dockerfile

# Force a rebuild on next run
safe-claude --rebuild
```

To pin a specific Claude Code version, pass the `CLAUDE_VERSION` build arg:

```bash
docker build --build-arg CLAUDE_VERSION=1.2.3 -t safe-claude:latest ~/safe_claude
```
