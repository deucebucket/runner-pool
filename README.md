# runner-pool

Claude Code plugin for orchestrating GitHub Actions self-hosted runners across any host. Add, list, remove, and health-check runners from any repo, any count, local or remote.

## Why

Self-hosted runners give you faster CI than GitHub-hosted (especially for big test suites or Android builds), and they avoid billing-meter consumption. The pain is the install ceremony — minting tokens, downloading the binary, wiring up systemd, doing it again per repo. This plugin makes the whole flow a one-liner.

## Commands

- `/runner:add` — install N runners on a host for the current (or specified) repo
- `/runner:list` — list runners registered for a repo
- `/runner:remove --name X` — deregister + uninstall a single runner
- `/runner:status` — pool health (online / offline / busy / idle / queued / by-host)

## Examples

```
/runner:add                                          # 1 runner, this workstation, current repo
/runner:add --count 3                                # 3 runners locally
/runner:add --host deucebucket@10.0.0.5 --count 2    # 2 on a remote host
/runner:add --repo deucebucket/other --count 1       # different repo
/runner:list
/runner:status
/runner:remove --name scrithub-workstation-2
```

## Requirements

- `gh` CLI authenticated with `actions:write` scope on the target repo
- ssh key auth to remote hosts (no-op for local)
- Linger enabled for the user (`loginctl enable-linger $USER`) so user-level systemd survives logout

## How it works

Each runner is a separate install dir on disk, registered with GitHub via a fresh registration token, run as a user-level systemd service capped at `MemoryHigh=2G MemoryMax=4G CPUQuota=200%`. Labels include `self-hosted,linux,x64` plus the host's short hostname (so workflows can pin to a specific host if needed).

## License

MIT.
