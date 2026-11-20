//! Own One Discovered ATA Port During Read Only Volume Matching

const ahci = @import("shared").ahci;
const identity = @import("tests").guest.ahci.volume;
const layout = @import("common").constants.memory.layout;
const pci = @import("tests").guest.ahci.pci;
const pmm = @import("mirai").pmm;
const registers = @import("tests").guest.ahci.registers;
const sizes = @import("common").constants.memory.sizes;
const transfer = @import("tests").guest.ahci.transfer;
const values = @import("tests").guest.constants.ahci.registers;

const Controller = ahci.types.discover.controller.Controller;
const Disk = @import("tests").guest.types.ahci.disk.Disk;
const ProbeError = @import("tests").guest.errors.ahci.transfer.ProbeError;
const Volume = @import("shared").boot.types.volume.Volume;
const bus = ahci.constants.discover.pci;
const wire = ahci.constants.command.dma;

pub fn match(device: Controller, aperture: u64, sata: u64, reclaimable: *bool, expected: Volume) !bool {
    if (registers.read(sata, values.ISSUE) != 0 or registers.read(sata, values.ACTIVE) != 0) return ProbeError.AhciPortBusy;
    if (!registers.stop(sata)) return ProbeError.AhciEngineDidNotStop;

    const physical = try pmm.allocate.single.allocatePage();
    defer if (reclaimable.*) pmm.free.single.freePage(physical);
    const page: *[sizes.PAGE_SIZE]u8 = @ptrFromInt(layout.PHYSMAP_BASE + physical);
    try ahci.command.encode.prepare(page, physical, .Identify);
    @memset(page[wire.FIS_OFFSET..wire.TABLE_OFFSET], 0);
    const global = registers.read(aperture, values.GHC);
    registers.write(aperture, values.GHC, global & ~values.GLOBAL_INTERRUPT);
    registers.write(sata, values.INTERRUPT_ENABLE, 0);
    registers.write(sata, values.LIST, @intCast(physical));
    registers.write(sata, values.LIST_HIGH, 0);
    registers.write(sata, values.FIS, @intCast(physical + wire.FIS_OFFSET));
    registers.write(sata, values.FIS_HIGH, 0);
    pci.commandBits(device.Address, device.Command | bus.BUS_MASTER);
    registers.write(sata, values.COMMAND, registers.read(sata, values.COMMAND) | values.RECEIVE_FIS);
    registers.write(sata, values.COMMAND, registers.read(sata, values.COMMAND) | values.START);

    const outcome = compare(sata, physical, page, expected);
    if (!registers.stop(sata)) {
        pci.commandBits(device.Address, device.Command & ~bus.BUS_MASTER);
        reclaimable.* = false;
        return ProbeError.AhciEngineDidNotStop;
    }
    registers.write(sata, values.LIST, 0);
    registers.write(sata, values.FIS, 0);
    pci.commandBits(device.Address, device.Command);
    registers.write(aperture, values.GHC, global);
    return outcome;
}

fn compare(port: u64, physical: u64, page: *[sizes.PAGE_SIZE]u8, expected: Volume) !bool {
    var disk: Disk = .{
        .Port = port,
        .Physical = physical,
        .Page = page,
        .Sectors = try transfer.identify(port, page),
    };
    return identity.match(&disk, expected);
}
