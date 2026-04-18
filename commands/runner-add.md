---
name: runner:add
description: Install N self-hosted GitHub Actions runners on a target host (local or remote) for the current (or specified) repo
argument-hint: "[--host HOST] [--count N] [--repo OWNER/REPO]"
---

Install self-hosted GitHub Actions runners. Defaults: current git repo, this workstation, count 1.

Run the underlying script with the supplied flags:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/runner-add.sh $ARGUMENTS
```

Examples:
- `/runner:add` → 1 runner on this workstation for the current repo
- `/runner:add --count 3` → 3 runners locally
- `/runner:add --host deucebucket@100.108.104.17 --count 2` → 2 runners on llm
- `/runner:add --repo deucebucket/some-other-repo --count 1` → 1 runner here for a different repo

After running, confirm with `/runner:status`.
