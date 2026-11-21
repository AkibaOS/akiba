//! Own And Drain One Kernel AHCI DMA Slot

const ahci = @import("shared").ahci;
const layout = @import("common").constants.memory.layout;
const pci = @import("mirai").device.pci.configuration;
const pmm = @import("mirai").pmm;
const registers = @import("mirai").device.ahci.registers;
const sizes = @import("common").constants.memory.sizes;
const values = @import("mirai").device.constants.ahci.registers;

const Controller = ahci.types.discover.controller.Controller;
const TransferError = @import("mirai").device.errors.ahci.transfer.TransferError;
const Use = @import("mirai").device.types.ahci.slot.Use;
const bus = ahci.constants.discover.pci;
const wire = ahci.constants.command.dma;

pub fn withSlot(device: Controller, aperture: u64, port: u64, reclaimable: *bool, context: *anyopaque, use: Use) !bool {
    if (registers.read(port, values.ISSUE) != 0 or registers.read(port, values.ACTIVE) != 0) return TransferError.AhciPortBusy;
    if (!registers.stop(port)) return TransferError.AhciEngineDidNotStop;

    const physical = try pmm.allocate.single.allocatePage();
    defer if (reclaimable.*) pmm.free.single.freePage(physical);
    const page: *[sizes.PAGE_SIZE]u8 = @ptrFromInt(layout.PHYSMAP_BASE + physical);
    try ahci.command.encode.prepare(page, physical, .Identify);
    @memset(page[wire.FIS_OFFSET..wire.TABLE_OFFSET], 0);
    const global = registers.read(aperture, values.GHC);
    const interrupts = registers.read(port, values.INTERRUPT_ENABLE);
    registers.write(aperture, values.GHC, global & ~values.GLOBAL_INTERRUPT);
    registers.write(port, values.INTERRUPT_ENABLE, 0);
    registers.write(port, values.LIST, @intCast(physical));
    registers.write(port, values.LIST_HIGH, 0);
    registers.write(port, values.FIS, @intCast(physical + wire.FIS_OFFSET));
    registers.write(port, values.FIS_HIGH, 0);
    pci.commandBits(device.Address, device.Command | bus.BUS_MASTER);
    registers.write(port, values.COMMAND, registers.read(port, values.COMMAND) | values.RECEIVE_FIS);
    registers.write(port, values.COMMAND, registers.read(port, values.COMMAND) | values.START);

    const outcome = use(context, .{ .Port = port, .Physical = physical, .Page = page });
    if (!registers.stop(port)) {
        pci.commandBits(device.Address, device.Command & ~bus.BUS_MASTER);
        reclaimable.* = false;
        return TransferError.AhciEngineDidNotStop;
    }
    registers.write(port, values.LIST, 0);
    registers.write(port, values.FIS, 0);
    registers.write(port, values.INTERRUPT_STATUS, registers.read(port, values.INTERRUPT_STATUS));
    registers.write(port, values.INTERRUPT_ENABLE, interrupts);
    pci.commandBits(device.Address, device.Command);
    registers.write(aperture, values.GHC, global);
    return outcome;
}
