//! Test-Owned Post Firmware AHCI DMA Probe

const ahci = @import("shared").ahci;
const bus = @import("tests").guest.constants.ahci.pci;
const guard = @import("asm").interrupts.guard;
const layout = @import("common").constants.memory.layout;
const pci = @import("tests").guest.mirai.drivers.pci;
const physmap = @import("mirai").kagami.tables.physmap;
const pmm = @import("mirai").pmm;
const registers = @import("tests").guest.mirai.drivers.registers;
const sizes = @import("common").constants.memory.sizes;
const transfer = @import("tests").guest.mirai.drivers.transfer;
const values = @import("tests").guest.constants.ahci.registers;

const ProbeError = @import("tests").guest.errors.ahci.ProbeError;
const wire = ahci.constants.command.dma;

pub fn readSector(sector: u64, destination: *[wire.SECTOR_BYTES]u8) !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const device = try pci.controller();
    const alias = try physmap.uncachedDevicePage(device.Bar);
    var safe_to_restore = true;
    defer if (safe_to_restore) physmap.restoreDevicePage(alias);
    const controller = layout.PHYSMAP_BASE + device.Bar;
    if (registers.read(controller, values.GHC) & values.AHCI_ENABLE == 0 or registers.read(controller, values.CAP2) & values.BIOS_HANDOFF != 0)
        return ProbeError.UnsupportedAhciController;
    const sata = try registers.selectPort(controller);
    if (registers.read(sata, values.ISSUE) != 0 or registers.read(sata, values.ACTIVE) != 0) return ProbeError.AhciPortBusy;
    if (!registers.stop(sata)) return ProbeError.AhciEngineDidNotStop;

    const physical = try pmm.allocate.single.allocatePage();
    defer if (safe_to_restore) pmm.free.single.freePage(physical);
    const page: *[sizes.PAGE_SIZE]u8 = @ptrFromInt(layout.PHYSMAP_BASE + physical);
    try ahci.command.encode.prepare(page, physical, .Identify);
    @memset(page[wire.FIS_OFFSET..wire.TABLE_OFFSET], 0);
    const global = registers.read(controller, values.GHC);
    registers.write(controller, values.GHC, global & ~values.GLOBAL_INTERRUPT);
    registers.write(sata, values.INTERRUPT_ENABLE, 0);
    registers.write(sata, values.LIST, @intCast(physical));
    registers.write(sata, values.LIST_HIGH, 0);
    registers.write(sata, values.FIS, @intCast(physical + wire.FIS_OFFSET));
    registers.write(sata, values.FIS_HIGH, 0);
    pci.commandBits(device.Command | bus.BUS_MASTER);
    registers.write(sata, values.COMMAND, registers.read(sata, values.COMMAND) | values.RECEIVE_FIS);
    registers.write(sata, values.COMMAND, registers.read(sata, values.COMMAND) | values.START);

    const outcome = transfer.read(sata, physical, page, sector);
    if (!registers.stop(sata)) {
        pci.commandBits(device.Command & ~bus.BUS_MASTER);
        safe_to_restore = false;
        return ProbeError.AhciEngineDidNotStop;
    }
    registers.write(sata, values.LIST, 0);
    registers.write(sata, values.FIS, 0);
    pci.commandBits(device.Command);
    registers.write(controller, values.GHC, global);
    try outcome;
    @memcpy(destination, page[wire.DATA_OFFSET..][0..wire.SECTOR_BYTES]);
}
