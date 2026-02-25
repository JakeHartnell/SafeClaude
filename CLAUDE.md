# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Is

`safe_claude` is a Docker-based sandbox that runs Claude Code with `--dangerously-skip-permissions` in an isolated environment. It protects the host system while allowing Claude to freely edit files, run shell commands, and install packages within the container.

## Commands

**First run / rebuild the Docker image:**
```bash
./safe-claude.sh --rebuild
```

**Run from any project directory (intended usage):**
```bash
cd /some/project
~/safe_claude/safe-claude.sh
```

**Set up the symlink for daily use:**
```bash
ln -s ~/safe_claude/safe-claude.sh ~/bin/safe-claude
```

**Pin a specific Claude Code version:**
```bash
docker build --build-arg CLAUDE_VERSION=1.2.3 -t safe-claude:latest .
```

## Architecture

There are only three files:

- **`safe-claude.sh`** — Entry point. Resolves symlinks to find the repo root, builds the Docker image if missing (or `--rebuild` is passed), then runs the container with:
  - `$PWD` mounted R/W as `/workspace`
  - `~/.claude` mounted R/W for config/memory persistence
  - `--dangerously-skip-permissions` passed to Claude Code
  - `--rm` so the container is cleaned up on exit

- **`Dockerfile`** — Builds the sandbox image from `node:20-slim`. Installs system tools (zsh, git, gh, ripgrep, fd-find, fzf, delta), creates a non-root `node` user, and installs `@anthropic-ai/claude-code` globally. History is persisted via a `/commandhistory` volume.

## Safety Model

**Sandboxed:** Host filesystem outside `$PWD`, system binaries, other users' files.

**Not sandboxed:** Network access, project files in `$PWD` (mounted R/W and changes are immediate), `~/.claude` config directory.

## Customization

Edit `Dockerfile` to add tools, then run `safe-claude --rebuild` to apply changes.
