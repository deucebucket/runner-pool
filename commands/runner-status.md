---
name: runner:status
description: Pool health for the current (or specified) repo — runner count, online/offline/busy/idle, queue depth, by-host breakdown. Suggests scale-up if queued.
argument-hint: "[--repo OWNER/REPO]"
---

Health check + queue depth report. If jobs are queued and no idle runners exist, suggests `runner-add` invocation.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/runner-status.sh $ARGUMENTS
```
