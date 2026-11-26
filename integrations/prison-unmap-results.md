# Prison checkpoint on RTX 4070 — adjacent unmaps

The baseline (dd82a87) counts request types for each CopyPageMappingsBatchX call. The candidate (cb3f13d) also joins directly adjacent, nonempty, aligned clears in the same call on the single-threaded path. A gap, repeated destination, source mapping, alignment mismatch or address overflow ends the run. The existing host mapping and notification routines apply each resulting range. The counter records high-level calls eliminated. It does not count eliminated Windows system calls. Both commits are local to the Cool Fox checkout on bench/prison-unmap-census.

Both runs used the Series S release configuration, a 512 MiB graphics buffer budget, the prison save, separately copied warmed caches, and the same timed Enter inputs. Each process was scheduled for 240 seconds before the capture and shutdown. The timing window starts with the second consecutive interval containing at least 500 draws per frame and spans 90 seconds. FPS is derived from timestamped presents. Pipeline and indirect drops are separate per-frame counters. Each configuration has one sample.

All 17 enabled Windows mapping tests passed. One microbenchmark was ignored. Tests included preserving an alias to the tail of a three-page host view when its first two pages are cleared, and preserving the sequence around repeated destinations and intervening source reads.


| First 90-second threshold window | Baseline | Joined clears |
|---|---:|---:|
| FPS | 3.39 | 3.62 |
| Median / P95 frametime (ms) | 186.6 / 862.1 | 146.7 / 781.5 |
| Longest interval (s) | 2.43 | 8.16 |
| Draws per frame | 3,570 | 1,479 |
| Pipeline / indirect drops per frame | 1,303 / 613 | 325 / 377 |
| Copy preparation / readback per frame (ms) | 45.2 / 40.0 | 35.5 / 31.7 |
| Readback per frame (MB) | 51.9 | 42.7 |

The baseline screenshot shows Lucia inside the prison looking into the yard. The candidate screenshot shows a severely overexposed, letterboxed outdoor shot. Both used checkpoint blob SHA-256 46350E4D452B131E84305EB92F7A6896BB595B822E7604AA9DA705A8E7A05883. Neither a fixed input schedule nor crossing 500 draws establishes matching progression. The different images and draw loads invalidate a like-for-like performance claim. The candidate's screenshot did not confirm a return to the cell at capture time. These two samples do not establish that joining caused the lighting difference.

After crossing the draw threshold through termination, the baseline counted 85,721 one-page map requests and 16,981 unmap ranges covering 91,127 pages. The candidate combined 91 of 12,351 unmap ranges (0.74%) in its post-threshold period. Neither recorded a sequential-source (kind 0) range. Individual one-page requests could still be adjacent in their backing section; the counters do not resolve their backing offsets. Both runs ended by benchmark shutdown. The mapping-test compilation started after the baseline's 90-second timing window and overlapped the final capture period.

Decision: keep the joined-clear experiment off. For further readback work, gate the timing window on confirmed cell entry and use a matched camera and draw workload. The known-working release binary retains SHA-256 A588077EFD6C1774BB1B563914F429BACE777020783440765896D6BC359E2F1B.
