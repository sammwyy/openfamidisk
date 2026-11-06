import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROM = Path(__file__).resolve().parents[1] / "build/disksys.rom"


@unittest.skipUnless(os.getenv("FDS_TEST_IMAGE"), "set FDS_TEST_IMAGE to run FCEUX integration")
class FceuxTests(unittest.TestCase):
    def test_boot_image(self):
        emulator = shutil.which("fceux")
        xvfb = shutil.which("xvfb-run")
        if not emulator or not xvfb:
            self.skipTest("fceux and xvfb-run are required")

        image = Path(os.environ["FDS_TEST_IMAGE"]).resolve()
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            bios = home / ".fceux" / "disksys.rom"
            bios.parent.mkdir()
            shutil.copyfile(ROM, bios)
            script = home / "test.lua"
            script.write_text(
                'local out = assert(io.open(os.getenv("HOME") .. "/result", "w"))\n'
                'local loading, booted, running = false, false, false\n'
                'for frame = 1, 660 do\n'
                '    emu.frameadvance()\n'
                '    loading = loading or (memory.readbyte(0xFE) == 0x0A\n'
                '        and ppu.readbyte(0x21CC) == 1 and ppu.readbyte(0x1010) == 0x60)\n'
                '    local action = memory.readbyte(0x0103)\n'
                '    booted = booted or (memory.readbyte(0x0102) == 0x35\n'
                '        and (action == 0xAC or action == 0x53))\n'
                '    local pc = memory.getregister("pc")\n'
                '    running = running or (booted and pc >= 0x200 and pc < 0xE000)\n'
                'end\n'
                'out:write(string.format("%d %d %d\\n", loading and 1 or 0,\n'
                '    booted and 1 or 0, running and 1 or 0))\n'
                'out:close()\n'
                'emu.exit()\n'
            )
            env = dict(os.environ, HOME=str(home), SDL_AUDIODRIVER="dummy")
            result = subprocess.run(
                [xvfb, "-a", emulator, "--no-config", "1", "--sound", "0",
                 "--loadlua", str(script), str(image)],
                env=env, capture_output=True, text=True, timeout=60,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual((home / "result").read_text(), "1 1 1\n")
