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
                'local loading, animated, booted, running = false, false, false, false\n'
                'local heard, early, stopped = false, false, false\n'
                'local gold, coral, bright, dim = false, false, false, false\n'
                'for frame = 1, 660 do\n'
                '    emu.frameadvance()\n'
                '    local visible = memory.readbyte(0xFE) == 0x0A\n'
                '        and ppu.readbyte(0x21C9) == 1 and ppu.readbyte(0x21CD) == 7\n'
                '        and ppu.readbyte(0x232A) == 19 and ppu.readbyte(0x236D) == 30\n'
                '        and ppu.readbyte(0x1010) == 0x73\n'
                '    loading = loading or visible\n'
                '    if memory.readbyte(0x0102) ~= 0x35 then\n'
                '        local triangle = math.floor(memory.readbyte(0x4015) / 4) % 2 == 1\n'
                '        if triangle then\n'
                '            heard = true\n'
                '            early = early or not visible\n'
                '        elseif heard then\n'
                '            stopped = true\n'
                '        end\n'
                '    end\n'
                '    if loading and memory.readbyte(0x0102) ~= 0x35 then\n'
                '        local border, stars = ppu.readbyte(0x3F05), ppu.readbyte(0x3F09)\n'
                '        gold = gold or border == 0x28\n'
                '        coral = coral or border == 0x27\n'
                '        bright = bright or stars == 0x30\n'
                '        dim = dim or stars == 0x28\n'
                '        animated = gold and coral and bright and dim\n'
                '    end\n'
                '    local action = memory.readbyte(0x0103)\n'
                '    booted = booted or (memory.readbyte(0x0102) == 0x35\n'
                '        and (action == 0xAC or action == 0x53))\n'
                '    local pc = memory.getregister("pc")\n'
                '    running = running or (booted and pc >= 0x200 and pc < 0xE000)\n'
                'end\n'
                'out:write(string.format("%d %d %d %d %d\\n", loading and 1 or 0,\n'
                '    animated and 1 or 0, booted and 1 or 0, running and 1 or 0,\n'
                '    heard and stopped and not early and 1 or 0))\n'
                'out:close()\n'
                'emu.exit()\n'
            )
            env = dict(os.environ, HOME=str(home), SDL_AUDIODRIVER="dummy")
            result = subprocess.run(
                [xvfb, "-a", emulator, "--no-config", "1", "--sound", "1",
                 "--loadlua", str(script), str(image)],
                env=env, capture_output=True, text=True, timeout=60,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual((home / "result").read_text(), "1 1 1 1 1\n")

    def test_smb_title_demo_keeps_game_nmi(self):
        image = Path(os.environ["FDS_TEST_IMAGE"]).resolve()
        if image.read_bytes()[16:19] != b"SMA":
            self.skipTest("requires Super Mario Bros FDS image")
        emulator = shutil.which("fceux")
        xvfb = shutil.which("xvfb-run")
        if not emulator or not xvfb:
            self.skipTest("fceux and xvfb-run are required")

        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            bios = home / ".fceux" / "disksys.rom"
            bios.parent.mkdir()
            shutil.copyfile(ROM, bios)
            script = home / "test.lua"
            script.write_text(
                'local out = assert(io.open(os.getenv("HOME") .. "/result", "w"))\n'
                'local alive = true\n'
                'for frame = 1, 1500 do\n'
                '    emu.frameadvance()\n'
                '    if frame == 1050 or frame == 1500 then\n'
                '        alive = alive and memory.readbyte(0x0102) == 0x35\n'
                '            and memory.readbyte(0x2000) >= 0x80\n'
                '    end\n'
                'end\n'
                'out:write(alive and "1\\n" or "0\\n")\n'
                'out:close()\n'
                'emu.exit()\n'
            )
            env = dict(os.environ, HOME=str(home), SDL_AUDIODRIVER="dummy")
            result = subprocess.run(
                [xvfb, "-a", emulator, "--no-config", "1", "--sound", "1",
                 "--loadlua", str(script), str(image)],
                env=env, capture_output=True, text=True, timeout=75,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual((home / "result").read_text(), "1\n")
