---
name: runner-orchestration
description: When to scale GitHub Actions self-hosted runners up or down across hosts — use when CI is queued, when a new repo is added to your worklist, or when a host changes
---

# Runner pool orchestration

You manage a pool of GitHub Actions self-hosted runners across one or more hosts. Use the `/runner:*` slash commands when CI behavior needs intervention.

## When to scale up

- `/runner:status` shows **queued jobs > 0 AND idle runners == 0** for >1 minute. Scale by `queued_count` runners on the fastest available host.
- A new repo is added to your worklist and has no runners yet. Run `/runner:add` from inside the repo (auto-detects `--repo`).
- A host is being added to the pool (e.g. a new dev machine). Run `/runner:add --host NEWHOST --count 2` for each repo that needs to run there.

## When to scale down

- `/runner:status` shows **idle == online for >24h** and queued is consistently 0. Removing 1-2 runners reclaims memory + saves systemd churn.
- A runner has gone offline persistently (per `/runner:status`) — remove with `/runner:remove --name OFFLINE_NAME`.
- A host is being decommissioned. Loop `/runner:remove --host OLDHOST --name <each>` to clean up GitHub-side registrations.

## Default placement

- **Workstation (this machine, GPU + faster CPU):** prefer for repos you're actively iterating on. Lower latency for log streaming back to the agent.
- **llm (production host):** prefer for repos that need to stay close to prod databases or have heavy disk I/O.
- **Other hosts:** add as you go.

## Anti-patterns

- Don't install >5 runners on a single host with `--count 5` in one shot if RAM is constrained — each runner caps at 4G memory but spawns N concurrent build workers that can spike further. Add 2-3, watch `htop`, then add more.
- Don't share a runner install dir across repos — each runner is registered to exactly one repo. Multi-repo support requires N independent installs.
- Don't run `/runner:add` from inside a worktree expecting it to install for the worktree's branch — the script reads the repo (origin) not the branch.

## Labels

Every runner gets `self-hosted,linux,x64` plus the host's short hostname automatically. Workflows dispatch on `runs-on: [self-hosted, linux, x64]` and any of the runners can pick the job up. To pin a job to a host, add the hostname to `runs-on`: e.g. `runs-on: [self-hosted, linux, x64, llm]` would only run on llm.
