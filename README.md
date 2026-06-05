# openbao_wrapper

**`bao-run`** — a tiny launcher wrapper that fetches secrets from
[OpenBao](https://openbao.org) (or HashiCorp Vault) via AppRole at start-up and
`exec`s your command with those secrets in its environment — so API keys, tokens,
and passwords never live in a `.env` file, a dotfile, a committed config, or a
process log.

```
bao-run KEY1 KEY2 ... -- command args...
```

The secrets exist only in the environment of the exec'd child, only for its
lifetime. `bao-run` itself never writes them to disk and never prints their
values.

## Why

The common advice — "export your API key in `~/.bashrc`" or "drop it in
`.env`" — leaves long-lived secrets sitting in plaintext on disk. `bao-run`
moves the boundary: the secret is pulled from your secret manager at the moment
a process launches, handed to that process via env, and never persisted. The
only thing on disk is the AppRole bootstrap (a role-id / secret-id that, on its
own, just lets you *log in* to fetch scoped secrets).

It pairs naturally with anything that reads a key from its environment:

```bash
# A server that wants DB_PASSWORD + API_TOKEN in env:
bao-run DB_PASSWORD API_TOKEN -- ./start-server.sh

# A systemd user unit — wrap ExecStart:
ExecStart=/home/me/.local/bin/bao-run API_TOKEN -- /usr/bin/myservice

# As a "command that prints a key" for tools that accept one
# (e.g. Cortex's CKN_API_KEY_CMD):
CKN_API_KEY_CMD='bao-run ANTHROPIC_API_KEY -- printenv ANTHROPIC_API_KEY'
```

## Install

Requires `bash`, `curl`, and `jq`.

```bash
git clone https://github.com/coreyzwart-zwtech/openbao_wrapper.git
cd openbao_wrapper
./install.sh            # symlinks bao-run → ~/.local/bin (use --copy to copy)
```

Make sure `~/.local/bin` is on your `PATH`.

## Configure

`bao-run` needs three values to authenticate, read from the environment (and
auto-sourced from `$BAO_ENV_FILE` when they aren't already set):

| Variable | Required | Meaning |
|---|---|---|
| `BAO_ADDR` | yes | OpenBao/Vault address, e.g. `https://openbao.example.com:8200` |
| `BAO_ROLE_ID` | yes | AppRole role-id |
| `BAO_SECRET_ID` | yes | AppRole secret-id |
| `BAO_SECRET_PATH` | no | KV v2 logical path holding your keys (default: `secret/app`) |
| `BAO_ENV_FILE` | no | File to source `BAO_*` from if absent (default: `~/.config/bao-run/env`) |

The simplest setup is a `chmod 600` bootstrap file that `bao-run` sources when
the creds aren't already in env:

```bash
mkdir -p ~/.config/bao-run
cat > ~/.config/bao-run/env <<'EOF'
BAO_ADDR=https://openbao.example.com:8200
BAO_ROLE_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
BAO_SECRET_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
BAO_SECRET_PATH=secret/app
EOF
chmod 600 ~/.config/bao-run/env
```

The keys you name on the command line are read from the single KV v2 entry at
`BAO_SECRET_PATH` (i.e. the entry's `data` map — `bao-run DB_PASSWORD ...` reads
the `DB_PASSWORD` field of that entry).

## How it works

1. Reads `BAO_ADDR` / `BAO_ROLE_ID` / `BAO_SECRET_ID` (from env, or `$BAO_ENV_FILE`).
2. AppRole login → a short-lived token.
3. One KV v2 read of `BAO_SECRET_PATH`; pulls each requested key from the entry.
4. Revokes the token (best-effort), then `exec env KEY=VALUE … -- your command`.

If login or the read fails, or a requested key is missing, it exits non-zero
with a short diagnostic to stderr — and never the secret values.

## Security notes

- Secrets are passed via the child's environment only; nothing is written to
  disk by `bao-run`.
- Values are never logged. Error messages reference key *names* and the path,
  never values.
- The login token is short-lived and revoked before handoff.
- Keep `~/.config/bao-run/env` `chmod 600`. The role-id/secret-id are scoped
  login creds, not the secrets themselves.

## License

[MIT](LICENSE) © Corey
