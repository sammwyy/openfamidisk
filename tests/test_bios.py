import unittest
from pathlib import Path

from py65.devices.mpu6502 import MPU


ROM = Path(__file__).resolve().parents[1] / "build/disksys.rom"


def block(payload):
    return list(payload) + [0, 0, 0, 0]


def disk(files, boot_id=0, game=b"ABC", side=0):
    info = bytearray(56)
    info[0] = 1
    info[1:15] = b"*NINTENDO-HVC*"
    info[16:19] = game
    info[21] = side
    info[25] = boot_id
    data = block(info) + block([2, len(files)])
    for file_id, address, kind, content in files:
        header = (
            [3, 0, file_id]
            + [0] * 8
            + [address & 255, address >> 8, len(content) & 255, len(content) >> 8, kind]
        )
        data += block(header) + block([4] + list(content))
    return data


class DiskMemory(list):
    def __init__(self, stream=(), inserted=True):
        super().__init__([0] * 65536)
        self.stream = list(stream)
        self.inserted = inserted
        self.ppu = []
        self.vram = {}
        self.ppu_addr = 0
        self.ppu_addr_high = True
        self.controls = []
        self.audio = []
        self[0xDFFC:0xDFFE] = [0, 0xC0]

    def __getitem__(self, key):
        if key == 0x4030:
            return 0x80 if self.stream else 0x40
        if key == 0x4031:
            if not self.stream:
                raise AssertionError("disk stream exhausted")
            return self.stream.pop(0)
        if key == 0x4032:
            return int(not self.inserted)
        if key == 0x2002:
            self.ppu_addr_high = True
            return 0x80
        return super().__getitem__(key)

    def __setitem__(self, key, value):
        if key == 0x2006:
            if self.ppu_addr_high:
                self.ppu_addr = (value & 0x3F) << 8
            else:
                self.ppu_addr = (self.ppu_addr & 0x3F00) | value
            self.ppu_addr_high = not self.ppu_addr_high
        if key == 0x2007:
            self.ppu.append(value)
            self.vram[self.ppu_addr] = value
            self.ppu_addr = (self.ppu_addr + 1) & 0x3FFF
        if key == 0x4025:
            self.controls.append(value)
        if isinstance(key, int) and (0x4000 <= key <= 0x400F or key == 0x4015):
            self.audio.append((key, value))
        super().__setitem__(key, value)


def machine(stream=(), inserted=True, reset=True):
    memory = DiskMemory(stream, inserted)
    memory[0xE000:] = ROM.read_bytes()
    cpu = MPU(memory=memory, pc=None if reset else 0xC100)
    return cpu, memory


def run_until(cpu, target, limit=150000):
    for _ in range(limit):
        if cpu.pc == target:
            return
        cpu.step()
    raise AssertionError(f"execution did not reach ${target:04X}: {cpu}")


class BiosTests(unittest.TestCase):
    def test_rom_layout_and_vectors(self):
        rom = ROM.read_bytes()
        self.assertEqual(len(rom), 8192)
        self.assertEqual(rom[-6:], bytes.fromhex("8be19feec7e1"))

    def test_boot_loads_program_and_ignores_nonboot_file(self):
        stream = disk([(0, 0x6000, 0, b"\xA9\x42\x60"), (3, 0x6100, 0, b"\x99")])
        cpu, mem = machine(stream)
        run_until(cpu, 0xC000)
        self.assertEqual(mem[0x6000:0x6003], [0xA9, 0x42, 0x60])
        self.assertEqual(mem[0x6100], 0)
        self.assertEqual(mem[0x0102:0x0104], [0x35, 0xAC])
        self.assertEqual(mem[0x2001], 0x06)
        self.assertEqual(mem[0x16], 0)
        self.assertEqual(mem[0x4015], 0)
        self.assertEqual(mem.stream, [0, 0])
        self.assertIn(0xED, mem.controls)
        self.assertEqual(mem.controls[-1], 0x2E)

    def test_cold_boot_displays_loading_screen(self):
        cpu, mem = machine(inserted=False)
        run_until(cpu, 0xE1F8)
        self.assertEqual(mem[0x2001], 0x0A)
        self.assertEqual(mem[0xFE], 0x0A)
        self.assertEqual(mem[0xFF], 0x90)
        self.assertGreater(len(mem.ppu), 1024)
        self.assertEqual(mem.ppu[-6:], [30, 31, 32, 33, 32, 31])
        self.assertEqual(mem[0x4000], 0x98)
        self.assertEqual(mem[0x4004], 0x72)
        self.assertEqual(mem[0x4008], 0x0E)
        self.assertEqual(mem[0x400C], 0x31)
        self.assertEqual(mem[0x4015], 0)

    def test_loading_animation_preserves_cpu_registers(self):
        cpu, mem = machine(inserted=False)
        run_until(cpu, 0xE1F8)
        cpu.a, cpu.x, cpu.y = 0x42, 0x21, 0x17
        for frame in range(1, 49):
            cpu.nmi()
            run_until(cpu, 0xE1F8)
        self.assertEqual((cpu.a, cpu.x, cpu.y), (0x42, 0x21, 0x17))
        self.assertEqual(mem[0x14], 48)
        self.assertEqual((mem.vram[0x3F05], mem.vram[0x3F09]), (0x26, 0x30))

    def test_stars_scroll_left_and_wrap_without_touching_the_title(self):
        cpu, mem = machine(inserted=False)
        run_until(cpu, 0xE1F8)
        positions = [0x2002, 0x200D, 0x2019, 0x2025, 0x2033, 0x203E,
                     0x2041, 0x204A, 0x2057, 0x2067, 0x2072, 0x207D,
                     0x2083, 0x208E, 0x209A, 0x20A9, 0x20B6,
                     0x20C0, 0x20CC, 0x20DB, 0x20E6, 0x20F1,
                     0x2284, 0x2291, 0x229C, 0x22A2, 0x22AD, 0x22B9,
                     0x22C8, 0x22D4, 0x22E5, 0x22FB]
        fixed = (0x2146, 0x2184, 0x219B, 0x21C9, 0x21CD,
                 0x2266, 0x232A, 0x236D)
        title = {address: mem.vram[address] for address in fixed}
        self.assertEqual((mem.vram[0x23C0], mem.vram[0x23C1],
                          mem.vram[0x23E8], mem.vram[0x23E9]), (0xBB, 0xEE, 0xBB, 0xEE))
        self.assertEqual([mem.vram[0x12A0 + row] for row in range(8)],
                         [0, 16, 56, 124, 56, 16, 0, 0])
        self.assertEqual([mem.vram[0x12B0 + row] for row in range(8)],
                         [0, 0, 24, 60, 24, 0, 0, 0])
        self.assertEqual([mem.vram[0x12C0 + row] for row in range(8)],
                         [0, 24, 60, 126, 126, 60, 24, 0])
        self.assertEqual([mem.vram[0x12D0 + row] for row in range(8)],
                         [0, 0, 0, 24, 24, 0, 0, 0])
        for phase in range(33):
            for index, address in enumerate(positions):
                shifted = (address & ~31) | ((address - phase) & 31)
                self.assertEqual(mem.vram[shifted], 42 + (index + phase) % 4)
                if phase:
                    old = (address & ~31) | ((address - phase + 1) & 31)
                    self.assertEqual(mem.vram[old], 0)
            self.assertEqual({address: mem.vram[address] for address in title}, title)
            if phase == 32:
                break
            for _ in range(8):
                cpu.nmi()
                run_until(cpu, 0xE1F8)
        self.assertEqual(mem[0x1C], 0)
        self.assertEqual(mem[0x1D], 0)

    def test_star_palettes_cycle_independently_of_border(self):
        cpu, mem = machine(inserted=False)
        run_until(cpu, 0xE1F8)
        self.assertEqual((mem.vram[0x3F05], mem.vram[0x3F09], mem.vram[0x3F0D]),
                         (0x28, 0x30, 0x3C))
        for border, warm, cool in [(0x27, 0x28, 0x2C), (0x26, 0x30, 0x3C),
                                   (0x30, 0x27, 0x30), (0x28, 0x30, 0x3C)]:
            for _ in range(8):
                cpu.nmi()
                run_until(cpu, 0xE1F8)
            self.assertEqual((mem.vram[0x3F05], mem.vram[0x3F09], mem.vram[0x3F0D]),
                             (border, warm, cool))

    def test_loading_arrangement_repeats_with_sustained_notes(self):
        cpu, mem = machine(inserted=False)
        run_until(cpu, 0xE1F8)
        notes = [0x96, 0, 0x86, 0, 0xC9, 0xB3, 0, 0xE1,
                 0xBD, 0xC9, 0xE1, 0, 0xE1, 0, 0xC9, 0,
                 0xBD, 0, 0xBD, 0xC9, 0xE1, 0xC9, 0xB3, 0x96,
                 0x86, 0xB3, 0x96, 0xC9, 0xBD, 0xE1, 0xC9, 0xE1]
        harmony = [0x52, 0xC4, 0x2D, 0x93, 0x67, 0xDF, 0x0C, 0x67,
                   0x93, 0x0C, 0x2D, 0x93, 0xC4, 0x2D, 0xC4, 0x2D]
        bass = [0x52, 0x2D, 0x67, 0x0C, 0x93, 0x2D, 0xC4, 0xC4]
        for index, note in enumerate(notes + notes[:2]):
            for _ in range(5):
                cpu.nmi()
                run_until(cpu, 0xE1F8)
            previous_audio = len(mem.audio)
            cpu.nmi()
            run_until(cpu, 0xE1F8)
            position = index % 32
            mask = 7
            if position % 4 == 0:
                mask |= 8
            self.assertEqual(mem[0x4015], mask)
            writes = mem.audio[previous_audio:]
            if note:
                self.assertEqual(mem[0x4002], note)
                self.assertEqual(mem[0x4003], 0)
            self.assertEqual((0x4003, 0) in writes, bool(note))
            if position % 2 == 0:
                self.assertEqual(mem[0x4006], harmony[position // 2])
                self.assertIn((0x4007, 1), writes)
            else:
                self.assertNotIn(0x4007, [address for address, _ in writes])
            if position % 4 == 0:
                self.assertEqual(mem[0x400A], bass[position // 4])
                self.assertIn((0x400B, 0x21), writes)
                self.assertEqual(mem[0x400E], 0x8C if position % 8 == 0 else 6)
                self.assertEqual(mem[0x400F], 0x18)
            else:
                self.assertNotIn(0x400B, [address for address, _ in writes])
                self.assertNotIn(0x400F, [address for address, _ in writes])
            self.assertEqual(mem[0x1A], 0)
            self.assertEqual(mem[0x1B], (position + 1) % 32)

    def test_loading_cue_waits_for_visible_screen(self):
        cpu, mem = machine(inserted=False)
        run_until(cpu, 0xE1F8)
        for _ in range(8):
            cpu.nmi()
            run_until(cpu, 0xE1F8)
        self.assertEqual(mem[0x4015], 15)
        stars = dict(mem.vram)
        phase = mem[0x1C:0x1E]
        mem[0x17] = 1
        cpu.nmi()
        run_until(cpu, 0xE1F8)
        self.assertEqual(mem[0x1A], 0)
        self.assertEqual(mem[0x1B], 0)
        self.assertEqual(mem[0x4015], 0)
        for _ in range(20):
            cpu.nmi()
            run_until(cpu, 0xE1F8)
        self.assertEqual(mem[0x4015], 0)
        self.assertEqual(mem.vram, stars)
        self.assertEqual(mem[0x1C:0x1E], phase)
        mem[0x17] = 0
        for _ in range(5):
            cpu.nmi()
            run_until(cpu, 0xE1F8)
        self.assertEqual(mem[0x4015], 0)
        cpu.nmi()
        run_until(cpu, 0xE1F8)
        self.assertEqual(mem[0x4015], 15)
        self.assertEqual(mem[0x4002], 0x96)

    def test_explicit_file_list_and_ppu_transfer(self):
        stream = disk([(0, 0x6100, 0, b"\x33"), (7, 0x0200, 1, b"\x01\x02\x03")])
        cpu, mem = machine(stream, reset=False)
        mem[0xC100:0xC109] = [0x20, 0xF8, 0xE1, 0x00, 0xC2, 0x20, 0xC2, 0xEA, 0xEA]
        mem[0xC200:0xC20A] = [0xFF] * 10
        mem[0xC220:0xC222] = [7, 0xFF]
        run_until(cpu, 0xC107)
        self.assertEqual(cpu.a, 0)
        self.assertEqual(cpu.y, 1)
        self.assertEqual(mem[0x6100], 0)
        self.assertEqual(mem.ppu, [1, 2, 3])
        self.assertEqual(mem[0x0200], 0)

    def test_wrong_disk_id_returns_error(self):
        cpu, mem = machine(disk([]), reset=False)
        mem[0xC100:0xC107] = [0x20, 0xF8, 0xE1, 0x00, 0xC2, 0x20, 0xC2]
        mem[0xC200:0xC20A] = [0xFF, ord("Z")] + [0xFF] * 8
        mem[0xC220] = 0xFF
        run_until(cpu, 0xC107)
        self.assertEqual(cpu.a, 4)
        self.assertEqual(cpu.y, 0)

    def test_missing_disk_returns_error(self):
        cpu, mem = machine(inserted=False, reset=False)
        mem[0xC100:0xC107] = [0x20, 0xF8, 0xE1, 0x00, 0xC2, 0x20, 0xC2]
        run_until(cpu, 0xC107)
        self.assertEqual(cpu.a, 1)
        self.assertEqual(cpu.y, 0)

    def test_truncated_disk_returns_error(self):
        cpu, mem = machine([1], reset=False)
        mem[0xC100:0xC107] = [0x20, 0xF8, 0xE1, 0x00, 0xC2, 0x20, 0xC2]
        run_until(cpu, 0xC107)
        self.assertEqual(cpu.a, 0x28)

    def test_invalid_signature_returns_error(self):
        stream = disk([])
        stream[1] = ord("?")
        cpu, mem = machine(stream, reset=False)
        mem[0xC100:0xC107] = [0x20, 0xF8, 0xE1, 0x00, 0xC2, 0x20, 0xC2]
        mem[0xC200:0xC20A] = [0xFF] * 10
        run_until(cpu, 0xC107)
        self.assertEqual(cpu.a, 0x21)

    def test_boot_id_loads_multiple_files_and_page_boundary(self):
        payload = bytes(range(256)) + b"\xA5\x5A"
        cpu, mem = machine(disk([(1, 0x60FF, 0, payload), (2, 0x7200, 0, b"skip")], boot_id=1))
        run_until(cpu, 0xC000)
        self.assertEqual(mem[0x60FF:0x6201], list(payload))
        self.assertEqual(mem[0x7200:0x7204], [0] * 4)

    def test_reset_resumes_game_when_warm_boot_marker_is_present(self):
        cpu, mem = machine([])
        mem[0x0102:0x0104] = [0x35, 0xAC]
        run_until(cpu, 0xC000)
        self.assertEqual(mem.controls, [])
        self.assertEqual(mem.ppu, [])
        self.assertEqual(mem[0x2000], 0x10)
        self.assertEqual(mem[0x4017], 0xC0)

    def test_invalid_cpu_destination_is_not_written(self):
        cpu, mem = machine(disk([(0, 0x2000, 0, b"\xA9\x77")]))
        run_until(cpu, 0xC000)
        self.assertEqual(mem[0x2000], 0x10)

    def test_vblank_wait_preserves_accumulator_and_action(self):
        cpu, mem = machine(reset=False)
        mem[0x0100] = 0xC0
        mem[0xFF] = 0x10
        mem[0xC100:0xC106] = [0xA9, 0x42, 0x20, 0xB2, 0xE1, 0xEA]
        for _ in range(100):
            if mem[0x0100] == 0 and mem[0x2000] == 0x90:
                break
            cpu.step()
        else:
            self.fail("VINTWait did not enable NMI")
        for _ in range(20):
            cpu.step()
        cpu.nmi()
        run_until(cpu, 0xC105)
        self.assertEqual(cpu.a, 0x42)
        self.assertEqual(mem[0x0100], 0xC0)
        self.assertEqual(mem[0x2000], 0x10)

    def test_game_nmi_vector_preserves_accumulator(self):
        cpu, mem = machine(reset=False)
        mem[0x0100] = 0xC0
        mem[0x0102:0x0104] = [0x35, 0xAC]
        mem[0x16] = 6
        mem[0xDFFA:0xDFFC] = [0, 0xC3]
        mem[0xC100:0xC103] = [0x4C, 0, 0xC1]
        cpu.a = 0x5A
        cpu.nmi()
        run_until(cpu, 0xC300, limit=100)
        self.assertEqual(cpu.a, 0x5A)
        self.assertEqual(mem[0x16], 6)
        self.assertEqual(mem[0x14], 0)

    def test_cold_boot_with_invalid_warm_marker_uses_loading_nmi(self):
        cpu, mem = machine(inserted=False)
        mem[0x0102:0x0104] = [0x35, 0]
        run_until(cpu, 0xE1F8)
        cpu.nmi()
        run_until(cpu, 0xE1F8)
        self.assertEqual(mem[0x14], 1)
        self.assertEqual(mem[0x0102], 0)


if __name__ == "__main__":
    unittest.main()
