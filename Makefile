ASM6F ?= asm6f
PYTHON ?= python3

.PHONY: all test clean

all: build/disksys.rom

build:
	mkdir -p build

build/disksys.rom: bios.asm | build
	$(ASM6F) bios.asm $@
	$(PYTHON) -c 'from pathlib import Path; p=Path("$@"); assert p.stat().st_size == 8192, "FDS BIOS must be 8192 bytes"'

test: all
	$(PYTHON) -m unittest discover -s tests -v

clean:
	$(RM) build/disksys.rom
