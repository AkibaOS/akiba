//! Own And Drain One ATA Port During Bootstrap Reads

const ahci = @import("shared").ahci;
const layout = @import("common").constants.memory.layout;
const pci = @import("mirai").device.pci.configuration;
const pmm = @import("mirai").pmm;
const registers = @import("mirai").device.ahci.registers;
const sizes = @import("common").constants.memory.sizes;
const transfer = @import("mirai").bootstrap.storage.transfer;
const values = @import("mirai").device.constants.ahci.registers;

const Controller = ahci.types.discover.controller.Controller;
const Disk = @import("mirai").bootstrap.types.storage.disk.Disk;
const Match = @import("mirai").bootstrap.types.storage.session.Match;
const StorageError = @import("mirai").bootstrap.errors.storage.read.StorageError;
const bus = ahci.constants.discover.pci;
const wire = ahci.constants.command.dma;

pub fn withDisk(device: Controller, aperture: u64, port: u64, reclaimable: *bool, context: *anyopaque, use: Match) !bool {
    if (registers.read(port, values.ISSUE) != 0 or registers.read(port, values.ACTIVE) != 0) return StorageError.AhciPortBusy;
    if (!registers.stop(port)) return StorageError.AhciEngineDidNotStop;

    const physical = try pmm.allocate.single.allocatePage();
    defer if (reclaimable.*) pmm.free.single.freePage(physical);
    const page: *[sizes.PAGE_SIZE]u8 = @ptrFromInt(layout.PHYSMAP_BASE + physical);
    try ahci.command.encode.prepare(page, physical, .Identify);
    @memset(page[wire.FIS_OFFSET..wire.TABLE_OFFSET], 0);
    const global = registers.read(aperture, values.GHC);
    registers.write(aperture, values.GHC, global & ~values.GLOBAL_INTERRUPT);
    registers.write(port, values.INTERRUPT_ENABLE, 0);
    registers.write(port, values.LIST, @intCast(physical));
    registers.write(port, values.LIST_HIGH, 0);
    registers.write(port, values.FIS, @intCast(physical + wire.FIS_OFFSET));
    registers.write(port, values.FIS_HIGH, 0);
    pci.commandBits(device.Address, device.Command | bus.BUS_MASTER);
    registers.write(port, values.COMMAND, registers.read(port, values.COMMAND) | values.RECEIVE_FIS);
    registers.write(port, values.COMMAND, registers.read(port, values.COMMAND) | values.START);

    const outcome = useAttached(port, physical, page, context, use);
    if (!registers.stop(port)) {
        pci.commandBits(device.Address, device.Command & ~bus.BUS_MASTER);
        reclaimable.* = false;
        return StorageError.AhciEngineDidNotStop;
    }
    registers.write(port, values.LIST, 0);
    registers.write(port, values.FIS, 0);
    pci.commandBits(device.Address, device.Command);
    registers.write(aperture, values.GHC, global);
    return outcome;
}

fn useAttached(port: u64, physical: u64, page: *[sizes.PAGE_SIZE]u8, context: *anyopaque, use: Match) !bool {
    var disk: Disk = .{
        .Port = port,
        .Physical = physical,
        .Page = page,
        .Sectors = try transfer.identify(port, page),
    };
    return use(context, &disk);
}
