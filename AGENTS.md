# Project style/instructions/whatever:

## Pico C projects
- C23. Use nullptr (never NULL), false/true, static_assert, prefer auto, add const where variable doesn't change.
- Functions without params don't use void (ie do test() and not test(void)).
- Target platform is Pico 2 (RP2350, not og Pico RP2040).
- Prefer binary notation (0b) instead of hex (0x), unless big number.
- Dev environment is gcc on macOS.
- Use tabs for indentation, not spaces.
- Headers use `#pragma once` after the copyright block instead of explicit `#ifndef` / `#define` include guards.
- File-local `static` helper functions should use short, local names without repeating the module/file prefix.
- Prefer project integer aliases from `shared_config.h` (`u32`, `i32`, etc.) over raw fixed-width types in project code.
- Use `likely(...)` / `unlikely(...)` from `pico-shared/utils.h` sparingly, only for branches that are genuinely expected to be heavily skewed.

### C Include/Header Layout
- For every `.c` (and applies to `.h`) use this exact order at the top WHEN WRITING NEW CODE, do not refactor during code review, etc
  1) `// copyright..` lines
  2) blank line
  3) `#pragma once` — only for `.h` files
  4) `#include "<module>.h"` — only for `.c` files, the header matching the `.c` (e.g., `aaa.c` includes `"aaa.h"`)
  5) blank line
  6) Angle includes: `#include <...>` — for headers not under `src/` (pico‑sdk, system headers, and anything from `lib/` such as `pico-shared`). Sort alphabetically (compare by the include string; case-insensitive; ignore folder semantics).
  7) blank line
  8) Quote includes: `#include "..."` — for headers under `src/`. Sort alphabetically (same rules as above).

- Notes:
  - Use `<...>` for system/SDK/external headers (pico-sdk, libc, etc) and for headers not maintained in this repo.
  - Use "..." for project-internal headers. This includes both `projects/phobos/src/**` and, when working inside the pico-shared library, any headers under `projects/phobos/lib/pico-shared/**` or `projects/phobos_old/lib/pico-shared/**`.
  - Keep exactly one blank line between these groups; omit a group (and its blank line) if it would be empty.

### Libraries under `lib/`
- Only edit `lib/pico-shared/**`. Treat other libraries under `lib/` as external (do not modify them) across all tasks unless explicitly instructed.

## Misc:
- Code style - mix between idiomatic language code and existing code style in files.
- Skip tests unless asked to implement tests. When asked to write tests - make them thorough, executing unit tests is fast, so cover all edge cases, etc. Do not modify code if newly found edge cases are failing.
