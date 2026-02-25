```
 ____         __        ____  _                 _
/ ___|  __ _ / _| ___  / ___|| | __ _ _   _  __| | ___
\___ \ / _` | |_ / _ \| |    | |/ _` | | | |/ _` |/ _ \
 ___) | (_| |  _|  __/| |___ | | (_| | |_| | (_| |  __/
|____/ \__,_|_|  \___| \____||_|\__,_|\__,_|\__,_|\___|

  Claude Code · --dangerously-skip-permissions · Docker sandbox
```

> Run Claude Code with full autonomy — without giving it full access to your machine.

SafeClaude wraps Claude's `--dangerously-skip-permissions` mode in a Docker container. Claude can freely edit files, run shell commands, and install packages — but only inside the sandbox. Your host system stays safe.

**Your project files are mounted read-write** into the container as `/workspace`, so Claude can see and edit everything in the directory you launch from. Changes are real and immediate — that's the point.

---

## Install

```bash
# Clone the repo
git clone https://github.com/JakeHartnell/SafeClaude.git ~/safe-claude

# Add a symlink so you can call it from anywhere
ln -s ~/safe-claude/safe-claude.sh ~/bin/safe-claude
# (make sure ~/bin is in your PATH)
```

That's it. The Docker image is built automatically on first run.

---

## Usage

```bash
cd /any/project
safe-claude
```

Claude opens with your current directory mounted as `/workspace` inside the container. Your `~/.claude` config and memory persist across sessions.

### Flags

| Flag | Description |
|------|-------------|
| `--rebuild` | Force a fresh Docker image build |
| `--help` | Show usage |

---

## What's sandboxed

```
HOST MACHINE                    DOCKER CONTAINER
─────────────────               ─────────────────────────────────
~/other-projects    (hidden)    /workspace  ← your project (r/w)
/etc, /usr, ...     (hidden)    ~/.claude   ← config + memory (r/w)
other users' files  (hidden)    full internet access
```

**Protected:** everything on your host outside the current project directory.

**Not protected:**
- Your **project files** — Claude can edit them freely (that's the whole point)
- **Network** — the container has full outbound internet so Claude can `npm install`, `git clone`, `curl`, etc.
- **`~/.claude`** — Claude config and memory are mounted so sessions persist across runs

> To disable network access: add `--network none` to the `docker run` call in `safe-claude.sh` (breaks package installs and API calls).

---

## Customizing the environment

Edit `Dockerfile` to add whatever tools your project needs, then rebuild:

```bash
vim ~/safe-claude/Dockerfile
safe-claude --rebuild
```

### Examples by project type

**Rust project:**
```dockerfile
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
```

**Foundry / Solidity project:**
```dockerfile
RUN curl -L https://foundry.paradigm.xyz | bash && \
    /root/.foundry/bin/foundryup
ENV PATH="/root/.foundry/bin:${PATH}"
```

**Python project:**
```dockerfile
RUN apt-get install -y python3 python3-pip python3-venv
```

Different projects need different toolchains — the Dockerfile is yours to extend.

### Pin a specific Claude Code version

```bash
docker build --build-arg CLAUDE_VERSION=1.2.3 -t safe-claude:latest ~/safe-claude
```

---

## Safety model

The sandbox protects your host by isolating Claude's actions inside a container. Claude gets `--dangerously-skip-permissions` so it never stops to ask for approval — it just does the work. The Docker layer is what keeps that safe.

Think of it as: **full autonomy, bounded blast radius.**

### vs. Claude Code's built-in sandbox

Claude Code has its own `/sandbox` feature (using Apple Seatbelt on macOS, bubblewrap on Linux) that restricts bash commands to `$PWD` and proxies network traffic. SafeClaude takes a different approach:

| | Built-in sandbox | SafeClaude (Docker) |
|---|---|---|
| **Isolation scope** | Bash commands only | Entire OS environment |
| **Filesystem** | R/W to `$PWD`, read-only elsewhere | Only `$PWD` and `~/.claude` visible |
| **Network** | Proxied, domain allowlist | Full access (or `--network none`) |
| **Overhead** | Lightweight, native | Full container startup |
| **Customizable env** | No | Yes — edit the Dockerfile |

The built-in sandbox is a good fit for interactive use on your own machine. SafeClaude is better when you want a fully reproducible, customizable environment — or when you're running Claude autonomously and want stronger isolation guarantees.
