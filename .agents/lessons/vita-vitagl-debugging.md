# Lessons: debugging PS Vita / vitaGL crashes

Hard-won knowledge from the 2026-06-08 inputty/boxy "FFP first-draw core-dump" investigation.
Read this before chasing the next Vita crash — it will save you several wrong turns.
Sibling artifacts: `~/git/inputty/.agents/handoff/2026-06-08-vitagl-ffp-legacy-pool-crash/HANDOFF.md`,
vitaGL branch `matt.spurlin/ffp-preprocessor-crash`.

---

## META-LESSON #1 — Do NOT trust a symbolicated PC from a Vita core dump until you've ruled out memory corruption

The original request blamed vitaGL's preprocessor because the core dump's PC symbolicated to
`preprocessor::writeTok`. That function is **dead code**, and the real bug was a NULL-pointer
scribble in a totally different subsystem. The symbolication was a *nearest-symbol artifact on a
smashed stack*.

**Corruption tells (any one of these ⇒ the PC is probably a wild jump, not the bug site):**
- The PC lands in **dead code**, in **read-only data** (past `.text`), or in an **unrelated module**.
- The **PC differs across runs** of the same crash (e.g. a `std::string` ctor one run, rodata the next).
- `lr` points into **`.bss`/unmapped memory**, or the saved return address on the stack is **not a code
  address** (we saw `0x3f800000` — a float — sitting where a return address should be).
- The "stack" is full of **application data** (see meta-lesson #3) rather than frames.

When you see these, **stop symbolicating and start localizing** (breadcrumbs + single-variable tests,
below). The dump tells you *that* memory was corrupted, not *where* the bug is.

## META-LESSON #2 — A non-deterministic PC + a *consistent* corrupted-arg signature = a smashed return address

Across runs we saw different PCs but the same garbage register pattern (`r0=0, r1=1, r2=1`, `lr` into
bss). Consistent garbage + variable landing spot = the corruption is upstream and deterministic; the
*jump target* is just whatever happened to be in the smashed return slot.

## META-LESSON #3 — `0x3f800000` is `1.0f`. Float-filled "stack/heap" regions are app vertex/color data scribbled by a runaway pointer

The dumps were full of `0x3f800000` because the app drew `glColor3f(1,1,1)` and a NULL-rooted vertex
pointer wrote that color across memory. If a dump region looks like repeated `0x3f80xxxx` / `0x3f00xxxx`
floats, ask "what graphics data is this, and which pointer is writing it unbounded?"

---

## vitaGL-specific gotchas

### `vglInit*` first arg = the GL1 immediate-mode "legacy pool" size. `0` + immediate-mode FFP = NULL-deref crash.
- `vglInit(poolSize)` / `vglInitWithCustomThreshold(poolSize, …)` — **the first argument is the
  immediate-mode vertex pool size**, NOT a generic/"default" knob.
- `source/vgl.c`: `legacy_pool_size = pool_size`. `source/gxm.c` allocates the pool **only** under
  `if (legacy_pool_size)`, so `0` leaves `legacy_pool_ptr == NULL`. `source/ffp.c` `glVertex*` then
  writes `legacy_pool_ptr[0]=x` with no guard → memory smash on the **first** `glBegin/glVertex/glEnd`.
- Stock samples work because they pass `vglInit(0x800000)` (8 MB). **If immediate-mode FFP draws crash on
  the first draw, check the pool size before anything else.**
- Fixed in vitaGL (`3a1e297`): `glBegin` now fails safe (GL_INVALID_OPERATION + no-op) when the pool is
  unallocated — but that draws nothing; the real fix is to pass a non-zero pool.

### FFP shaders do NOT go through vitaGL's C++ preprocessor.
- The fixed-function pipeline builds Cg with `sprintf` and hands it **straight to SceShaccCg/vitashark**.
- `source/utils/preprocessor/preprocessor.cpp` (`glsl_preprocess`) is reached **only** by *custom* GLSL
  shaders via `glCompileShader`/`glLinkProgram` (`glsl_translator_process`). Don't blame the preprocessor
  for an FFP crash.

### vitaGL's GLSL→Cg preprocessor had real, separate bugs (fixed in `e08bf78`) — relevant only to *custom* shaders.
- It `strcpy`'d expanded output into a `strlen(input)`-sized buffer (heap overflow), and `throw`'d
  `std::string` across an `extern "C"` boundary → `std::terminate`. Both fixed (bounded copy + boundary
  catch → clean `GL_LINK_STATUS == GL_FALSE`). This is the fix for **boxy's `#version 300 es`** link crash.
- Default semantic mode is `VGL_MODE_POSTPONED`: custom-shader translation/compile happens at
  **`glLinkProgram`**, not `glCompileShader`. So `glGetShaderiv(GL_COMPILE_STATUS)` returns `GL_TRUE`
  even for a doomed shader; the real status is `glGetProgramiv(GL_LINK_STATUS)`.

---

## How to read a `.psp2dmp` core dump (no `vita-parse-core` needed)

1. It's a **gzip-compressed ELF core**. `gunzip` it; it becomes `ELF 32-bit LSB core file, ARM`.
2. Statically-linked homebrew loads **with no ASLR at link base `0x81000000`**, so a PC in
   `0x81000000`–`<.text end>` maps **1:1 to the unstripped `.elf`** — `arm-vita-eabi-addr2line -f -C -i -e
   app.elf 0x<pc>` just works. (Keep the unstripped `*.elf` from the build; `vita-elf-create` runs on it.)
3. **Code segments are usually NOT dumped** (only writable/stack regions appear as `PT_LOAD`). Rely on the
   1:1 ELF mapping for code; use the dumped LOADs for stack/heap inspection.
4. **Register layout** — parse the `PT_NOTE` named `THREAD_REG_INFO` (note type `0x1004`). Descriptor:
   `u32 unk, u32 nThreads, u32 entrySize(=0x178)`, then `nThreads` entries. Per entry, as `u32 words[]`:
   `words[0]=thread_id`, then **`r0=words[1]` … `r12=words[13]`, `sp=words[14]`, `lr=words[15]`,
   `pc=words[16]`, `cpsr=words[17]`**. Verify the mapping against a kernel/worker thread: its `pc` should
   be `~0xe00xxxxx` and `cpsr` `0x00000010`/`0x40000010`/`0x60000010`.
5. **Identify the app** — the `APP_INFO` note (type `0x101c`) holds the TITLE_ID + app name. Multiple apps'
   dumps coexist in `ux0:data/`; always confirm *which app* (and check mtime / filename timestamp)
   before analyzing — it's easy to grab the wrong dump.
6. The **faulting thread** is the one whose `pc` is in your app's range while the others sit in kernel waits.

A working parser skeleton (Python, stdlib only) lived in `/tmp/vgl_core/*.py` during the investigation —
re-derive from the layout above; it's ~30 lines.

---

## Techniques that actually cracked it (use these, in order)

1. **Breadcrumb-to-disk.** Native aborts are uncatchable, so log progress to a file and **flush by
   closing it** after every step (`sceIoOpen(... O_APPEND); write; close`). After the crash, the **last
   line on disk names the step that died.** This single technique localized a "wild jump" crash to one
   exact call (`glBegin`) in one device run.
2. **Single-variable on-device experiment.** Change exactly ONE thing (we flipped `pool_size` 0→8 MB,
   nothing else) and compare. Crash→pass on a one-variable diff is conclusive; don't change two things
   (e.g. pool size *and* a library guard) in the same build or you can't attribute the result.
3. **Host harness for the pure-C++ parts.** vitaGL's preprocessor is standard C++ — compile
   `preprocessor.cpp + expression.cpp` on the host with a stub `vitasdk.h` (`#include <stdint.h>`) and a
   `vglMalloc` shim, then feed it real shader sources. Reproduced/cleared the preprocessor hypotheses
   off-device in seconds. (`vgl_log` is a no-op macro by default, so no logging stubs needed.)
4. **Bisect with a git worktree at the parent commit.** `git worktree add /tmp/x <parent>`, build the lib
   there, build a copy of the test app against it with a **distinct TITLE_ID and distinct output
   filenames**, install both, compare. This is how we exonerated the CDRAM-display-allocator commit.

---

## Build / deploy mechanics (paper cuts)

- **`make install` needs sudo** (`/usr/local/vitasdk/...`). To test a local lib build without installing,
  link the sample against the in-repo `libvitaGL.a` via `LIBS = -L../.. -lvitaGL …` (samples sit at
  `samples/<name>/`, so `../..` is the repo root). The installed header is fine if you didn't change
  `vitaGL.h`.
- **Each VPK needs a unique 9-char `TITLE_ID`**; reinstalling the same ID **overwrites** in place (handy
  for iterate-in-place; dangerous if you mean to compare two builds — give them different IDs).
- **Confirm the build actually linked your lib**: `arm-vita-eabi-nm app.elf | grep <symbol>` should show
  it as `T` (defined), and check the link line shows your `-L` first.
- **VPK = `param.sfo` + `eboot.bin`**. Flow: `make` (lib) → `make -C samples/<name>` (vpk). Copy to the SD
  card root, install via VitaShell, results land in `ux0:data/`.
- **Verify a card copy**: `md5 -q src.vpk` == `md5 -q /Volumes/<card>/dst.vpk`, then `sync` before eject.
- **ASan is unusable on this macOS host** — even a trivial `-fsanitize=address` binary hangs at startup.
  Don't burn time on it; use plain builds + correct-by-construction reasoning (and the host harness).

---

## The one-paragraph version

A Vita "it crashes on the first FFP draw" with `vglInit*(0, …)` is almost certainly the **legacy pool
size = 0** NULL-deref, not whatever the core dump's PC says — Vita dumps mis-symbolicate badly on a
smashed stack. Localize with **breadcrumbs-to-disk**, confirm with a **one-variable** rebuild, and
remember **FFP ≠ the GLSL preprocessor**. Pass a non-zero `pool_size` when using immediate-mode FFP.
</content>
