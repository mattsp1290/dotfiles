# Beans (`bn`) CLI conventions

Use `bn` as the shared issue tracker. Issues live in the shared hub; project resolution comes from the current Git repository. Use `--project <name>` only when working on a different project.

## Daily work

- `bn ready`, `bn list`, `bn show <id>`, `bn blocked`, and `bn children <id>` inspect work.
- `bn create "Short title" -d "details" -p 0 -t task -l label --silent` creates an issue and captures its ID.
- `bn update <id> --claim` claims work; `bn update <id> --note "text"` or `bn note <id> "text"` records progress.
- `bn close <id> -r "reason"`, `bn reopen <id>`, and `bn delete <id> [--force]` manage lifecycle.
- `bn dep add CHILD PARENT` means the child is blocked until the parent closes. Ready work is `open` with no open blockers. Use `bn dep remove`, `bn dep tree`, and `bn dep cycles`; never create cycles.

Keep titles short; put useful acceptance context in `-d`. Use priority, type, and label flags when they help triage.

## Hub lifecycle and recovery

Run mutating `bn` commands serially: the hub has a lock. Every mutation commits and pushes the hub automatically; never manually commit or push hub state. `bn status` observes hub state, `bn sync` forces synchronization, and `bn doctor` diagnoses problems. Exit code 4 means another `bn` holds the lock; wait for that operation to finish, then retry once or use `bn status`/`bn doctor`. Exit code 3 is a Git failure; use `bn sync` before retrying. Do not use raw hub Git writes as a workaround.

`bn init <remote>` creates or clones the shared hub only. It is never a per-project initializer; a first write creates that project's hub directory.
