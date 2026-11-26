# RTX 4070 optimization record

## Reproduction

The guest is on H: NVMe. The isolated per-run profile, cache, captures and logs are on F:. Seed copying and hashing finish before the timed process starts. Windows, NVIDIA GeForce RTX 4070, 12,282 MiB reported by nvidia-smi, driver 621.40. Pinned Cool Fox f4b48ad766ddbec1a1867022cd42f7645b0dd55e with checkpoint instrumentation. Apply integrations/cool-fox-patches, then integrations/architecture-patches in numerical order in each directory, inside the submodule. Build with cargo build --release --offline --locked -p victory with dependencies cached. Joined unmaps remain off. The unsuccessful readback micro-optimization is on a separate branch.

Guest identity b99f876b74d4a77f03af5f878223b27bd647b5c35a79d5decd9f716504239e93; prison save payload SHA-256 46350E4D452B131E84305EB92F7A6896BB595B822E7604AA9DA705A8E7A05883. Separate per-run save and warmed cache copies (237,140,656-byte input PSO library). Series S, 1920 x 1080 captured client area; internal dynamic-resolution scale unknown. The standard launcher numeric environment is loaded from Play-VIctory.cmd; 512 MiB buffer budget, one map thread, relay=2, relay copy enabled, ambient estimate=0.8, air=1.5, BVH builder default off. Each new run retains the full environment settings manifest and binary hash. Enter every five seconds from 15 through 90 seconds. Captures every 15 seconds; use the first and final continuous 60-second windows at the cell window, with grayscale scene correlation above 0.90 and visual inspection. Report percentiles of complete present intervals. 1% low is the reciprocal of the mean of the slowest ceil(N/100) intervals. On the renderer run scripts/checkpoint_stats.py TRACE START_EPOCH_MS --seconds 60. A title-bar FPS reading is insufficient.

## Measurements and decisions

The prior settled control recorded 10.50 FPS, 6.10 FPS 1% low, median 94.84 ms, P95 114.83 ms and P99 145.48 ms. Early cell timing was 8.02 FPS, 0.69 FPS 1% low, P95 201.71 ms and P99 678.93 ms. Camera matching matters. These windows are from one run. Matching wall time from startup can compare the cutscene to the playable cell. Retain the control launcher for play.

The earlier ordered-unmap experiment combined 0.74% of post-threshold clear ranges and did not establish a win. The CPU merge experiment reduced isolated merge time but regressed the settled capture to 9.87 FPS, 4.46 FPS 1% low and 194.88 ms P99. These experiments do not justify changing the default.

Texture admission and eviction were crediting retired ranges as spendable until the next allocation discovered that they were still resting. The pool now maintains its free-list byte total under the same lock as range split, retirement, maturation and block reclamation. A 32 MiB retirement no longer increases the credit by 32 MiB before maturity. A separate driver-error path kept a texture range and a COM callback forever after failure to attach the callback. The revised path discards the unpublished D3D12 texture before the last callback reference retires its piece. An isolated hardware test forced 128 attachment failures; all 8 MiB retired and the block was reclaimed. This establishes rollback correctness, not a diagnosis of the game's normal memory growth.

## Architecture and correctness

The loader and HLE preserve guest virtual addressing and aliases. GPU shadows, before-images, upload staging, host placed textures and tiled mip backing can represent different versions or layouts of the same guest bytes. A mirror may be needed for an intervening CPU write or a shader reading a different alias. DXGI shared usage and process working set overlap; shadow span is address coverage, not a physical memory sum. The new telemetry attributes writeback to regular and relay paths, and splits relay host shadows from card-backed resources. Byte counts measure what each merge reports, not PCIe bus traffic. Preparation time and host fence wait are elapsed CPU-side intervals; neither is GPU execution time. Existing D3D12 timestamp infrastructure lives in host/stamps.rs and host/spans.rs. Compare equivalent submission sets with VICTORY_CARD_SPANS in a diagnostic build before changing barriers or queue ordering.

Static geometry traversal uses translated BVH node tests; dynamic acceleration structures depend on the builder compute pipelines. pipeline::builder_runs requires a complete set. With the builder off, ambient.rs substitutes screen-space irradiance after the title's probe resolve. A visible bunk under that estimate does not establish correct ray tracing. Binding validation, depth and exposure, genuine indirect light, reflections and shadow fidelity require pass-level comparison. Unknown pipeline creation slots 0x1c8 and 0x218 still return E_NOTIMPL; their contribution to missing draws is unresolved.

Review scope included the architecture and RT journal, the nine crate boundaries, previous fork comparisons and experiments, and source paths for mapping, GPU resource ownership, staging, relay queues, descriptors, shader/BVH translation and pipeline caching. This is not a line-by-line audit of all source. On the external side, D3D12MA (MIT, 6009492) separates allocated bytes, unused ranges and the largest unused range. Microsoft's D3D12TranslationLayer (MIT, 81f92db) associates deferred deletion with last-used command-list IDs and completion requirements. Our renderer also has guest aliases, dynamic descriptors and outstanding landing work. Establish those dependencies before replacing its retirement delay. No external allocator code was imported.

## Scenario coverage

| Scenario | Repeatable evidence or dependency |
|---|---|
| Loading and shader creation | Warm-cache launch logged from first present; separate splash, menu and cutscene by capture. A cold-cache run and compiler-only timing remain outstanding. |
| Intro sequence | Fixed Enter schedule and 15-second captures. Segment by visible sequence, not elapsed startup time. |
| Interior | Verified prison cell and fixed camera; primary quantitative baseline. |
| Exterior | Yard visible from cell is a lighting observation. A standalone exterior checkpoint/camera has not been verified. |
| Dense driving | Requires a verified accessible vehicle, fixed route, weather and recorded inputs. No corresponding save identified in the benchmark seed. |
| Interior to exterior | Requires repeatable traversal from a known exit; validate both sides and the transition. |
| Extended play | This short stationary run can reveal retention but cannot establish a leak rate. Repeat a fixed traversal and compare memory after fence retirement at successive returns. |

Capture dedicated and shared DXGI budget/use, process commit and working set separately. Distinguish genuinely empty blocks, fragmented free ranges, and still-retiring pieces before changing the spare cap. Preserve PSO cache identity when comparing drivers. No controlled AMD run on this PC; upstream AMD timings are context only. Register pressure, occupancy, actual render resolution, native RT correctness, shader compiler timings, per-pass GPU costs, committed-vs-evicted texture churn and route-specific streaming remain open measurements.

## RTX 4070 prison capture, November 26

Both 60-second settled windows used the same guest, prison save, input sequence, Series S settings, warm shader/PSO seed and camera. The candidate binary SHA-256 was B6678D2EBFAD2A6F9E6E9E37C72005C0C179FC2C3116F25121ADF64EF21C0E54. Guest executable SHA-256 was E95020B2FA4A721DB3DF59FDECF75621730AC559D8835252F6C3B658D5A08993. Inspecting the capture confirms the character, bunk, foreground wall and sunlit yard. The screen-space lighting estimate was active. There is no reference-console image establishing material, exposure or indirect light accuracy.

| 60-second window | FPS | 1% low FPS | P50 ms | P95 ms | P99 ms | Draws/frame | Pipeline drops/frame | Indirect counter/frame |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Settled control | 10.50 | 6.10 | 94.84 | 114.83 | 145.48 | 4451 | 260 | 596 |
| Early candidate | 8.25 | 1.55 | 108.07 | 184.55 | 452.31 | 4606 | 268 | 591 |
| Settled candidate | 10.48 | 6.52 | 96.50 | 118.62 | 148.77 | 4405 | 255 | 593 |

The first verified minute included a 1,121 ms frame. The worst settled frame took 177 ms. The settled candidate averaged 61.52 ms of submission preparation, 16.78 ms of host-side GPU wait and 35.94 ms in writeback. These timers can overlap across threads. All 45.21 MB/frame of writeback was attributed to the relay, split between host-backed shadows (24.94 MB) and card-backed copies (20.27 MB). This supports investigating relay work before redesigning the direct path. No statistically established frame-rate gain.

| Memory, MiB | Settled median | Run peak |
|---|---:|---:|
| Process private commit | 22,328 | 23,106 |
| Process working set | 17,888 | 19,698 |
| DXGI local usage | 8,506 | 8,509 |
| DXGI nonlocal usage | 5,757 | 6,529 |
| Texture upload staging | 47 | 475 |
| Available texture-pool ranges | 981 | 3,168 |

The settled median local budget was 10,270 MiB. A large amount of pool free space warrants a per-block census. Free bytes can be scattered through live heaps. The new optional census reports whole-empty bytes, largest contiguous free range, retired bytes and range count. The camera remained stationary. These measurements cannot establish a leak, fragmentation across a driving route, or that lowering the spare cap would release a corresponding amount of VRAM.

### Lighting and shader validation

A new Series S run changed the builder option and enabled pipeline and ambient logging. It exited with a guest null write at image offset 0x23cf683 (callers 0x2215c35 and 0x2215eca). The previous Series X traced run failed at the same instruction. No successful builder dispatch was confirmed before the failure. The guest also reported falling back after an unimplemented FSR4 pipeline-creation call. The evidence does not establish that this fallback caused the null write. Next compare guest-visible creation results and descriptor types at the first divergence between the known working and builder-enabled captures. Keep the lighting estimate separately labeled.

The 16 CPU traversal tests, three ambient tests and eight allocator tests passed. A separate forced-failure hardware test exercised COM lifetime rollback. The six shader-intersection regressions passed with DXIL validator 1.9, including hardware and WARP comparisons using synthetic 32- and 64-bit node pointers. The installed SDK 10.0.19041 exposes DXIL validator 1.5; five of those six cases faulted with it. Both validator revisions were checked through IDxcVersionInfo. Select a compatible validator using VICTORY_DXIL for these tests. This offline validator difference does not explain the live guest crash.

### Reproducing another scenario

From PowerShell 7 run integrations/Measure-Checkpoint.ps1 with -Executable, -Game (the executable alongside the title DLLs), -ProfileSeed, -CacheSeed, -LauncherDefaults (the pinned Play-VIctory.cmd), -OutputRoot and -Scenario. Pass the same -Keys sequence and -Seconds to each A/B run. The runner creates a new working directory for each launch, hashes the executable and save inputs, records graphics settings, timestamps presents and captures the client every 15 seconds. A scenario name labels the run. Verify the actual scene from the captures. Use -CacheMode ColdShaders to omit shader entries and the PSO binary while preserving loader images and queue priority hints. The OS file cache and NVIDIA driver cache are outside that definition. Private run directories contain local profiles and frames; keep them outside Git.

### Subsequent regressions and controls

The experimental relay bookkeeping change passed seven ordering and merge tests. Its final prison capture failed the visual comparison. The candidate left wall averaged approximately 12/255 versus 65/255 in the control and the yard was brighter. No complete 60-second window passed the existing reference-correlation threshold. The change was removed from the integration. This single run does not prove the bookkeeping caused the lighting failure. A separate in-place range-sort fixture returned identical ranges and duplicate-byte totals, but saved only 12 microseconds per 2,048-piece iteration. That change remains experimental.

The relay experiment's final minute had median 6,208 MiB of texture heaps, 1,301 MiB of free ranges and only 128 MiB in completely empty heaps. Thus 1,173 MiB of free ranges were in partly occupied heaps. At peak 1,860 MiB were still waiting for retirement. This motivated testing occupied-first allocation, which leaves live and retired placements fixed and considers only otherwise eligible heaps.

The null write at image offset 0x23cf683 uses an absolute zero destination encoded in the instruction. The stack also leads through a fatal callback. This identifies a deliberate guest failure path; it does not identify the earlier condition that triggered it. No guest instructions were changed.

The earlier cache seed contains 2,727 translated entries, but the relay capture observed zero shader hits during initial loading. The copied PSO library loaded successfully. Supplying that same seed kept the historic scenario comparable but did not establish warm shader hits. A preliminary timing build also invalidated shader keys when instrumentation changed a fingerprinted file. Its startup results are excluded. The integrated converter timing is outside the translator fingerprint and measures translation plus serialization on worker threads, before publication. The replacement protocol uses a cache populated by the measured renderer family, keeps the loader images and queue hints fixed, and records actual hits. A completed warm/cold pair on the NVMe is outstanding. OS and driver caches are uncontrolled.

The profile's settings.xml SHA-256 is 558C63CA0073281E52487C52238BE017CED26837D62E49F896F00ACF537A4D22. It requests HDR off, FSR quality value 2, a 30 FPS limit, VSync value 2 and 3840 x 2160 fullscreen. The launcher selects Series S. The client-area measurement and the guest's requested fullscreen mode describe different layers. Neither establishes actual per-pass internal resolution.

### NVMe checkpoint

The pre-NVMe tests above loaded game data from H: but built the renderer and populated per-run shader caches, profiles and logs on F:. They are a mixed-storage baseline. End-to-end NVMe measurements must be labeled separately. The benchmark on F: was stopped before the occupied-first A/B completed. Its early samples do not validate either setting.

For the H: run, use an isolated renderer checkout and Cargo target under H:\GTA6 and pass -RequireDrive H: to Measure-Checkpoint.ps1. That option checks the renderer executable, guest executable, launcher defaults, profile and cache seeds and output root before creating the run. The runner gives the child process a temporary directory inside its own run directory. Use a copy of the verified prison save and keep the original H: launcher and saves intact. The primed cache contained 5,304 shader entries. Check observed shader-cache hits and visual capture for each run. Run integrations/startup_stats.py RUN_DIRECTORY --seconds 60 for translation-worker time, first present and hit/miss counts. For the prison camera use integrations/prison_scene.py REFERENCE_PNG CANDIDATE_PNG and inspect both images beside the per-region intensity results.

The isolated occupied-first fixture left one 64 MiB heap reclaimable and kept the live piece at the same placement; the prior placement order kept both heaps allocated. The release build and all nine enabled pool tests passed, with one separately opt-in hardware fault-injection test. This is a synthetic fragmentation result. Real gameplay memory savings, visual equivalence, pacing and NVMe startup are open. The allocator experiment is in `integrations/experiments/occupied-first-texture-heaps.patch`. Apply it with `git apply` in a separate Cool Fox checkout after the numbered patches. The proposed behavior requires `VICTORY_PACK_TEXTURE_HEAPS=1` or the runner's `-PackTextureHeaps`. Run the same instrumented binary with the switch absent for control.
