# OpenFamiDisk

An open-source Famicom Disk System BIOS written in 6502 assembly. It builds an 8,192-byte raw ROM for the `$E000–$FFFF` address range, without an iNES header. It contains no Nintendo ROM code or extracted graphics or audio assets.

## Status

**Prototype, not yet a general replacement for `disksys.rom`.** Cold boots display a dark starfield, an unfilled chamfered border with animated warm colors and a single-line `NOW LOADING...` title, and an `OpenFamidisk v0.1.0` credit below it. A short Nyan Cat melody loops on the NES triangle channel while the loading title is visible, pauses during PPU transfers, and stops before the disk program starts. The BIOS reads the disk identification and file count blocks, processes file headers and data, selects boot files by Boot ID, and transfers data to PRG-RAM or the PPU. `LoadFiles` (`$E1F8`) accepts two pointers placed after `JSR` and a file ID list terminated by `$FF`; it returns an error code in A and the number of loaded files in Y.

The NMI/IRQ vectors, reset entry point, and a few basic utilities have their own implementations. Many other BIOS entry points retain only their addresses: write calls do not write to disk, and the unimplemented graphics and controller routines do no useful work. CRC validation, save writes, the disk insertion/side-change menu, and full RAM adapter timing are not implemented. Games that require those routines **are not supported**. A locally supplied disk image successfully booted into its program in FCEUX 2.6.6; this does not establish compatibility with other games or emulators.

The loading screen temporarily uses `$0400–$06FF` to preserve CHR tiles until boot completes. Boot files that write to this RAM range may conflict with it.

## Build and test

Requires [asm6f](https://github.com/freem/asm6f), `make`, and Python 3. Install `py65==1.2.0` in your Python environment to run the CPU tests.

```sh
make
make test
```

If `asm6f` is not on `PATH`, use `make ASM6F=/path/to/asm6f`. The output is `build/disksys.rom`. Unit tests execute the built ROM in a 6502 CPU emulator (`py65`) with simulated disk and PPU registers. To run the optional FCEUX integration test with your own FDS image, install `fceux` and `xvfb-run`, then run:

```sh
FDS_TEST_IMAGE=/path/to/game.fds make test
```

The integration test checks that the loading screen appears and the BIOS transfers control to the disk program. It uses an isolated temporary home directory for FCEUX. Disk images are not included in the project.

## Format and references

The API addresses, vectors, block layout, and loading protocol were investigated using the original FDS BIOS as a behavioral reference and NESdev's [FDS BIOS](https://www.nesdev.org/wiki/FDS_BIOS) and [FDS disk format](https://www.nesdev.org/wiki/FDS_disk_format) documentation. The original ROM is neither included in the project nor needed to build it.

Credit to **James Athey** for [FreeDiskSysROM](https://github.com/jamesathey/FreeDiskSysROM), an earlier open-source BIOS effort that helped identify the API surface and the status of existing implementations. Its code is licensed under LGPL-3.0 and **has not been incorporated** into this project.

## License

Copyright 2026 OpenFamiDisk contributors. Licensed under the [Apache License 2.0](LICENSE).
