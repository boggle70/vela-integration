# vela-integration

riscv-vela 레포들을 묶어 하나의 통합 빌드·부팅 확인을 수행한다. 각 레포의 PR CI 와는 별개이며 PR 필수 체크가 아니다.

## 1단계 범위

[q-vela README](https://github.com/riscv-vela/q-vela#launch) "Launch" 절의 부팅 구성:

| 레포 | 산출물 | 빌드 절차 근거 |
|---|---|---|
| q-vela | `qemu-system-riscv64` | q-vela README "Build QEMU" |
| vela-fws | `fw_dynamic.bin` (Security Monitor 포함 OpenSBI) | vela-fws README "TEE — Building OpenSBI + Security Monitor" |
| vela-linux | `Image`, `keystone-driver.ko` | vela-linux README "Building" |
| vela | `ubuntu-noble-riscv64.qcow2` | vela README, `init.sh` |

통과 기준: 위 네 산출물로 부팅해 serial 에 getty prompt `<hostname> login:` 이 나온다.

1단계에서 제외한 것

| 대상 | 이유 |
|---|---|
| vela-apps | sdk C++ 가 GCC 13 에서 `uintptr_t` 오류로 빌드되지 않는다 |
| vela-fws edk2, buildroot | RAS 부팅 경로(q-vela `docs/ras.md`). 2단계 |
| vela-ros, t-vela, f-vela 등 | 부팅 구성에 포함되지 않는다 |

## 구조

```
default.xml                 repo manifest (레포·revision 목록)
scripts/resolve.sh          branch → SHA 확정, lock.xml 생성
scripts/fetch.sh            lock 의 SHA 로 레포 하나를 받는다 (depth 1)
scripts/cache-key.sh        산출물 cache key: <레포>-<SHA>-<빌드 스크립트 hash>
components/<레포>.sh        deps: apt 패키지 목록 / build <src> <out>: 빌드
compose/boot-test.sh        부팅 시험
.github/workflows/integration.yml
```

레포가 `ci/integration-build.sh` 를 제공하면 `components/<레포>.sh build` 는 그 스크립트를 `<out>` 인자로 실행한다.
제공하지 않는 동안은 `components/` 스크립트가 레포 README 의 절차를 대신 수행한다.

## 실행

GitHub Actions: 매일 02:00 KST, 또는 Actions 탭 → integration → Run workflow (`force` 로 성공 이력 무시).
레포 SHA 와 스크립트가 직전 성공 때와 같으면 빌드를 건너뛴다.

로컬 (Ubuntu 24.04 x64, sudo 필요):

```sh
scripts/resolve.sh default.xml lock.xml
for c in q-vela vela-fws vela-linux vela; do
  sudo apt-get install -y $(components/$c.sh deps)
  scripts/fetch.sh lock.xml $c src/$c
  components/$c.sh build src/$c out/$c
done
compose/boot-test.sh out
```

repo 도구로 트리를 받으려면: `repo init -u <이 레포 URL> -m default.xml && repo sync`

## 실행으로 확인한 것

GitHub Actions run [39816688832](https://github.com/boggle70/vela-integration/actions/runs/39816688832),
[39819321537](https://github.com/boggle70/vela-integration/actions/runs/39819321537),
[39822455084](https://github.com/boggle70/vela-integration/actions/runs/39822455084) 기준.

| 항목 | 결과 | 빌드·시험 step 소요 |
|---|---|---|
| apt 교차 컴파일러(`riscv64-linux-gnu-`)로 OpenSBI + Security Monitor 링크 | 성공 (vela-fws) | 43초 |
| GitHub runner 에서 `init.sh` (losetup, qemu-user chroot) | 성공 (vela) | 9분 22초 |
| TCG 부팅, getty login prompt 까지 | 성공 (boot-test) | 20~30초 (`BOOT_TIMEOUT` 기본 3600초) |

## 남은 위험

- `vela-fws/sm/rust-toolchain.toml` 이 `channel = "nightly"` 로 날짜를 고정하지 않아 실행일에 따라 결과가 달라질 수 있다
