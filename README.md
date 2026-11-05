# vela-integration

Builds the riscv-vela repositories together and checks that the combined stack boots.
It is separate from each repository's PR CI and is not a required PR check.

## Principles

- This repository takes a version configuration, builds and tests it as given, and reports the result (pass/fail) to the owners.
- It does not add workarounds or changes to the target repositories' sources or build procedures. Failures are reported, not fixed here.
- Versions follow the riscv-vela release format `vYY.MM` (e.g. `v26.11`; see
  [profile/repo.md](https://github.com/riscv-vela/.github/blob/main/profile/repo.md)).
  The maintainers decide which release of each repository a version includes; this repository carries out that decision.
- `default.xml` pins each repository to a commit. The maintainer checks the upstream branches for changes, runs the integration build
  on a branch with the new pins, and merges it by pull request once it passes, so `main` holds the last integrated configuration.
- The build runs only on a manual request. There is no scheduled, push or pull request trigger.

## Stage 1 scope

The boot configuration in the "Launch" section of the [q-vela README](https://github.com/riscv-vela/q-vela#launch):

| Repository | Output | Build procedure source |
|---|---|---|
| q-vela | `qemu-system-riscv64` | q-vela README "Build QEMU" |
| vela-fws | `fw_dynamic.bin` (OpenSBI with the Security Monitor) | vela-fws README "TEE — Building OpenSBI + Security Monitor" |
| vela-linux | `Image`, `keystone-driver.ko` | vela-linux README "Building" |
| vela | `ubuntu-noble-riscv64.qcow2` | vela README, `init.sh` |

Pass criterion: booting with the four outputs above prints the getty prompt `<hostname> login:` on the serial console.

Excluded from stage 1

| Target | Reason |
|---|---|
| vela-apps | The sdk C++ code fails to build with GCC 13 (`uintptr_t` error) |
| vela-fws edk2, buildroot | RAS boot path (q-vela `docs/ras.md`). Stage 2 |
| vela-ros, t-vela, f-vela, etc. | Not part of the boot configuration |

## Layout

```
default.xml                 repo manifest (repositories and revisions)
scripts/resolve.sh          resolve branch → SHA, write lock.xml
scripts/fetch.sh            fetch one repository at the SHA in the lock (depth 1)
scripts/cache-key.sh        output cache key: <repo>-<SHA>-<build script hash>
scripts/report.sh           report failed jobs as issues that mention the owners
components/<repo>.sh        deps: apt package list / build <src> <out>: build
compose/boot-test.sh        boot test
.github/workflows/integration.yml
```

If a repository provides `ci/integration-build.sh`, `components/<repo>.sh build` runs that script with `<out>` as its argument.
Until then, the `components/` scripts carry out the build procedure from the repository's README.

## Running

GitHub Actions runs the integration build only on a manual request: Actions tab → integration → Run workflow,
or `gh workflow run integration --ref <branch|tag>` (`force` ignores the previous success record).

If the repository SHAs and scripts are the same as in the last successful run, the build is skipped.

### Failure reports

After the other jobs, the `report` job opens an issue in this repository for each failed job and mentions its owners,
so they get a GitHub notification (by email if they enabled it):

| Failed job | Mentioned |
|---|---|
| `build (<repo>)` | the `owners` annotation of the repository in `default.xml` |
| `resolve`, `boot-test` | `REPORT_OWNERS` in `integration.yml` |

The issue is titled `integration: <job> failed` and carries the lock and the end of the failed step's log.
If the issue is already open, a later failure adds a comment; when the job passes again, the issue is closed.
Outside riscv-vela (e.g. in a fork) only the user who started the run is mentioned, and nothing is reported if the
repository has issues disabled.

### Updating the configuration

1. Check the latest commit of each repository's `upstream` branch:
   `git ls-remote https://github.com/riscv-vela/<repo> refs/heads/<upstream>`
2. Put the new SHA in the project's `revision` in `default.xml` on a branch (in a fork, on the fork's branch).
3. Run the integration build on that branch: `gh workflow run integration --ref <branch>` (in a fork, the run uses the fork's Actions).
4. Open a pull request with the run link; merge it when the build and boot test pass.

Locally (Ubuntu 24.04 x64, sudo required):

```sh
scripts/resolve.sh default.xml lock.xml
for c in q-vela vela-fws vela-linux vela; do
  sudo apt-get install -y $(components/$c.sh deps)
  scripts/fetch.sh lock.xml $c src/$c
  components/$c.sh build src/$c out/$c
done
compose/boot-test.sh out
```

To fetch the tree with the repo tool: `repo init -u <this repository URL> -m default.xml && repo sync`

## Known risks

- `vela-fws/sm/rust-toolchain.toml` uses `channel = "nightly"` without a pinned date, so results may differ depending on the run date.
