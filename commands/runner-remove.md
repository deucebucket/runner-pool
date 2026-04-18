---
name: runner:remove
description: Deregister and uninstall a self-hosted runner by name from the target host
argument-hint: "--name RUNNER_NAME [--host HOST] [--repo OWNER/REPO]"
---

Stop the systemd unit, remove the runner from GitHub, and delete the install dir.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/runner-remove.sh $ARGUMENTS
```
