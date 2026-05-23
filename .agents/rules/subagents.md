# Sub-Agent Delegation

You are Opus. Use sub-agents to parallelize work and move faster without sacrificing quality.

## Model routing

**Sonnet** — the implementation workhorse. Use for:
- Writing or refactoring code, including across multiple files
- Generating tests, fixtures, and test utilities
- Code review of changes (use vibes-core:RedOwl when available)
- Migrations, config changes, and boilerplate
- Documentation that requires reading and synthesizing code

**Haiku** — fast and cheap. Use ONLY for:
- Searching for files, symbols, or patterns (Explore agent type)
- Checking whether something exists
- Reading and summarizing configuration or documentation
- Gathering information to inform your decisions

**Haiku must never write code that will be committed.** If a task requires judgment or correctness, use Sonnet.

## Agent limitations

Sub-agents **cannot**:
- **Write or edit files** — they have no access to the Edit or Write tools. They can only read files, search, and run shell commands. All file creation happens via Bash (cat, heredoc, echo) inside the agent.
- **Do web research** — no WebSearch or WebFetch tools. Provide all necessary context in the prompt. Don't ask agents to look something up online.
- **See conversation history** — each agent starts fresh. Everything it needs must be in the prompt.

## How to delegate well

- **Give full context.** Include relevant file paths, existing patterns to follow, function signatures to match, and acceptance criteria. A sub-agent with poor context produces poor code.
- **One clear task per agent.** Agents work best with a focused, self-contained objective and explicit expected output.
- **Parallelize independent work.** Launch multiple agents in a single message when tasks don't depend on each other (e.g., writing tests for module A while refactoring module B, or searching three different areas of the codebase).
- **Don't parallelize coupled work.** If two changes share state, need consistent naming, or must integrate at a boundary — do them sequentially or do them yourself.

## CWD drift with worktree agents

Background worktree agents can leave the shell's cwd pointing at a worktree directory (e.g., `.claude/worktrees/agent-xxx/`). After any background agent completes, **always `cd` back to the repo root** before running git commands or checking file paths. Symptoms: `git status` shows a clean tree when you expect changes, `ls` can't find files you know exist, or `git log` shows the wrong history.

## Your role as orchestrator

- Break implementation into parallelizable units and delegate them
- Review sub-agent output before committing — you are the quality gate
- Handle integration, sequencing, and anything requiring full conversation context yourself
- When a sub-agent's output needs adjustment, fix it directly rather than re-delegating
- **Don't run tests while background agents are still writing files** — wait for completion signals first
