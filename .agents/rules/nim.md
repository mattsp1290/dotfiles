# Nim Project Conventions

## Every Nim project needs a `nim.cfg` for editor LSP to work

Nim resolves `import foo/bar` against a **search path**, not relative to the
importing file. `nimble build` compiles the `bin` entry (e.g. `src/myapp.nim`),
so the compiler's path includes `srcDir` (`src/`) and imports like `game/render`
resolve to `src/game/render.nim`.

Editor language servers (Zed's Nim LSP, nimlangserver, nimlsp) type-check each
file **as its own root** with no knowledge of nimble's `srcDir`. Without `src/`
on the path, `import game/render` from inside `src/game/run.nim` fails with:

```
Error: cannot open file: game/render
```

...followed by cascading `undeclared identifier` errors as the failed imports
never load. The build is green; only the editor is red.

### The fix

Add a `nim.cfg` at the **repo root** (committed) containing:

```
--path:"src"
```

Nim reads `nim.cfg` files by walking **up** the directory tree from whatever
file it's compiling, so a single root-level `nim.cfg` applies to every module
and gives the LSP the same `src/` search path nimble gives the build. Paths in
`nim.cfg` are resolved relative to the config file's own location, so
`--path:"src"` means `<repo>/src`.

### Checklist when scaffolding or touching a Nim repo

- Ensure a root `nim.cfg` exists with `--path:"src"` (match it to `srcDir` in the
  `.nimble` file if that differs).
- Commit `nim.cfg` — it's a real project file, not editor-local state.
- Verify both paths resolve the same way:
  - `nim check --hints:off src/<sub>/<file>.nim` should exit `0` (this is what
    the LSP effectively runs per-file).
  - `nimble build` should still produce the binary.
