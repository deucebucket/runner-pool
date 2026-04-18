---
name: runner:list
description: List all self-hosted runners registered for the current (or specified) repo, with status + labels
argument-hint: "[--repo OWNER/REPO]"
---

List runners registered with GitHub for the current repo (or one passed via `--repo`).

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/runner-list.sh $ARGUMENTS
```
