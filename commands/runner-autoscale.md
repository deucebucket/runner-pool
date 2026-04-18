---
name: runner:autoscale
description: Continuously monitor queue depth and scale runners up/down on a host. Defaults to current repo, this workstation, min=1 max=8, 10min cooldown, 30s poll interval.
argument-hint: "[--min N] [--max N] [--cooldown SEC] [--interval SEC] [--host HOST] [--repo OWNER/REPO]"
---

Run as a foreground autoscaler loop. For background, suffix with `&` or wrap in a systemd user unit.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/runner-autoscale.sh $ARGUMENTS
```

Examples:
- `/runner:autoscale` — default policy, this workstation, current repo
- `/runner:autoscale --min 2 --max 6` — keep at least 2 always running, cap at 6
- `/runner:autoscale --cooldown 1800` — wait 30 min idle before scaling down
