<!--
SPDX-License-Identifier: MIT
SPDX-FileCopyrightText: 2026 FALINUX Co., Ltd.
-->
<!-- REUSE-IgnoreStart: the examples below are not tags of this file -->

# SPDX tags — reference adoption guide

This repository carries its license and copyright in each file as SPDX tags, and checks them at commit time.
This guide describes how it is done here, so that another repository can adopt the same scheme by following it.

## 1. The tags

Each file gets two lines:

```
SPDX-License-Identifier: <license>
SPDX-FileCopyrightText: <year> <organization>
```

- `<license>`: an SPDX license identifier (for example `MIT`, `Apache-2.0`, `BSD-3-Clause`,
  `GPL-2.0-only`). Use the license of the tree the file belongs to: the repository's `LICENSE`, unless the
  directory has a license file of its own.
- `<year> <organization>`: the year the file was written and the organization that holds the copyright, in
  the same form as in `LICENSE`.

In this repository:

```
SPDX-License-Identifier: MIT
SPDX-FileCopyrightText: 2026 FALINUX Co., Ltd.
```

## 2. Where the tags go

The tags go at the top of the file, inside a comment in the style of the file: on the first lines, after the
`#!` line of a script, or after the `<?xml …?>` declaration of an XML file.

| File type | Form |
|---|---|
| Shell, Python, YAML, Makefile, CMake | `# SPDX-License-Identifier: …` |
| C source (`.c`) | `// SPDX-License-Identifier: …` |
| C header (`.h`) | `/* SPDX-License-Identifier: … */` |
| Markdown | an HTML comment block at the top |
| XML | an XML comment right after the `<?xml …?>` declaration |

Examples from this repository: `scripts/fetch.sh` (after `#!`), `components/lib.sh` (first line),
`default.xml`, `README.md`.

## 3. Which files get tags

Compare each file with its origin file by file; the commit history alone does not tell where a file came
from.

| File | What to do |
|---|---|
| Written for the repository | add the tags |
| Taken from another project and changed, or derived from one | add the tags above the existing notice; do not change or remove the notice |
| Taken from another project unchanged | leave it as it is and do not list it |

In this repository every file is tagged except `LICENSE` and `LICENSES/MIT.txt` (license texts),
`.git-commit-template` (not written for this repository) and the data files `.reuse/targets.txt` and
`.reuse/check-mode`, which tools read as plain lists and cannot hold comments.

Add the lines by hand. A file that cannot hold a comment (binary, generated) is out of the scope of this
guide; the REUSE specification describes `.license` files and `REUSE.toml` for that case.

## 4. Repository files

| File | Content |
|---|---|
| `LICENSES/<license>.txt` | the license text, from `reuse download <license>` |
| `.reuse/targets.txt` | the tagged files, one path per line, no comments, no whitespace in paths. It is the scope of the checks below |
| `.reuse/check-mode` | `off`, `warn` or `enforce` (section 6) |
| `.githooks/pre-commit` | the commit-time check (section 6) |

Keep `.reuse/targets.txt` up to date: add a new file that gets tags, and remove a file that is deleted or
renamed.

## 5. Checking the whole list

```sh
xargs reuse lint-file < .reuse/targets.txt    # exit 0 when every listed file is tagged
```

`reuse lint` checks every file in the repository, so it fails while any file has no tags (here
`.git-commit-template`); use `lint-file`. Install `reuse` with `pipx install reuse`; the `lint-file` command
is required (this repository uses reuse 6.3.0).

## 6. Commit-time check

Enable the hook once per clone:

```sh
git config core.hooksPath .githooks
```

`core.hooksPath` replaces `.git/hooks`: hooks you keep in `.git/hooks` no longer run while it is set.
`git config --unset core.hooksPath` turns the hook off again.

On each commit the hook checks, with `reuse lint-file`, the staged content of the staged files listed in
`.reuse/targets.txt`. A listed file that is renamed is checked under its new name. Two cases are reported
as reminders and never block the commit:

- a file added in the commit but not listed (files under `LICENSES/` and `.reuse/`, and
  `.githooks/pre-commit`, are left out);
- a listed file deleted or renamed in the commit while the list still names it.

`.reuse/check-mode` selects what happens when a check fails:

| Mode | Behavior |
|---|---|
| `off` | no check |
| `warn` | report the problems, the commit goes ahead (default, also when the file is missing) |
| `enforce` | report the problems, the commit is aborted (also for any value other than `off` and `warn`) |

- The mode is case-insensitive.
- The mode and the list are read as staged, like the files: the committed setting applies, and a local
  edit that is not staged does not change it.
- If `reuse` is not installed, `warn` goes ahead with a message and `enforce` aborts.

What the hook does not do:

- It runs only in clones that enabled it, and `git commit --no-verify` skips it for one commit. Turning it
  off for everyone takes a commit that changes `.reuse/check-mode`, which shows in review.
- It runs locally only; it is not part of the GitHub workflow, so nothing checks the tags on the server.

## 7. Adopting the scheme in another repository

1. Copy `.githooks/pre-commit` as it is; it holds no repository-specific values. Keep its own tags
   (MIT, FALINUX Co., Ltd.); as an unchanged file from another project it is not listed in
   `.reuse/targets.txt` (section 3). Add `LICENSES/MIT.txt` if the repository does not have it, so that
   the MIT tag in the hook refers to a license text in the repository.
2. Add `LICENSES/<license>.txt` and `.reuse/check-mode` with `warn`.
3. Tag the files (sections 1–3) and list them in `.reuse/targets.txt`.
4. Check: `xargs reuse lint-file < .reuse/targets.txt`.
5. Ask the developers to enable the hook (`git config core.hooksPath .githooks`).
6. Once the tags are routine, change `.reuse/check-mode` to `enforce` in a pull request.

A file that shows tags as examples, like this guide, wraps them in `REUSE-IgnoreStart` and `REUSE-IgnoreEnd`
comments so that the checks do not read them as its own tags.
<!-- REUSE-IgnoreEnd -->
