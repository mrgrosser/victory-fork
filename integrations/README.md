# Cool Fox

The `cool-fox` submodule pins the DoubleGhosty mirror of codec_d's NVIDIA renderer. It builds independently of the parent workspace.

```powershell
git submodule update --init -- integrations/cool-fox
Set-Location integrations/cool-fox
cargo build --locked --release -p victory
```

The included `Play-VIctory.cmd` selects the Series S profile. Set `VICTORY_DATA_DIR` to a separate copy of the checkpoint profile and `VICTORY_CACHE_DIR` to a directory for this renderer.

On one RTX 4070, the Series S release with a 512 MiB GPU buffer budget showed the clearest interior in the prison doorway trial. It averaged 4.40 FPS during the first 90 seconds of sustained scene draws. The faster Series X trial used the same launcher settings with `--console series-x` and `VICTORY_CARD_BUFFERS_MB=1280`. It averaged 6.67 FPS in that window and 10.14 FPS in the last minute. The wall was dark and the doorframe was purple. Both profiles had long stalls.

The optional measurement and adjacent-unmap experiments are in cool-fox-patches/. From the parent repository, initialize the pinned submodule and apply the numbered patches in order:

    git submodule update --init integrations/cool-fox
    git -C integrations/cool-fox switch -c bench/prison-remaps
    Get-ChildItem integrations/cool-fox-patches/*.patch | Sort-Object Name | ForEach-Object { git -C integrations/cool-fox am $_.FullName; if ($LASTEXITCODE) { throw "Patch failed" } }

The joined-unmap experiment requires VICTORY_JOIN_UNMAPS=1. See prison-unmap-results.md for timings and the scene mismatch.
