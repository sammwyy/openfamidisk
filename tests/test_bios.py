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
        self.controls = []
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
            return 0x80
        return super().__getitem__(key)

    def __setitem__(self, key, value):
        if key == 0x2007:
            self.ppu.append(value)
        if key == 0x4025:
            self.controls.append(value)
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
        self.assertEqual(mem.stream, [0, 0])
        self.assertIn(0xED, mem.controls)
        self.assertEqual(mem.controls[-1], 0x2E)

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
        mem[0xDFFA:0xDFFC] = [0, 0xC3]
        cpu.a = 0x5A
        cpu.nmi()
        run_until(cpu, 0xC300)
        self.assertEqual(cpu.a, 0x5A)


if __name__ == "__main__":
    unittest.main()
