//! Bounded Q35 ICH9 Native Read Only Probe

const std = @import("std");

const ahci = @import("shared").ahci;
const cpu = @import("asm").cpu;
const guard = @import("asm").interrupts.guard;
const layout = @import("common").constants.memory.layout;
const physmap = @import("mirai").kagami.tables.physmap;
const pmm = @import("mirai").pmm;
const port = @import("asm").io.port;
const sizes = @import("common").constants.memory.sizes;
const values = @import("mirai").drivers.constants.ahci;

const wire = ahci.constants.command;

pub fn readSector(sector: u64, destination: *[wire.SECTOR_BYTES]u8) !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (pci(values.PCI_ID) != values.ICH9_ID or pci(values.PCI_CLASS) >> values.REVISION_BITS != values.AHCI_CLASS)
        return error.AhciControllerMissing;
    const command: u16 = @truncate(pci(values.PCI_COMMAND));
    const bar = pci(values.PCI_BAR);
    if (command & values.MEMORY_ENABLE == 0 or bar == 0 or bar & values.BAR_FLAGS != 0) return error.InvalidAhciBar;
    const alias = try physmap.uncachedDevicePage(bar);
    var safe_to_restore = true;
    defer if (safe_to_restore) physmap.restoreDevicePage(alias);
    const controller = layout.PHYSMAP_BASE + bar;
    if (read(controller, values.GHC) & values.AHCI_ENABLE == 0 or read(controller, values.CAP2) & values.BIOS_HANDOFF != 0)
        return error.UnsupportedAhciController;
    const sata = try selectPort(controller);
    if (read(sata, values.ISSUE) != 0 or read(sata, values.ACTIVE) != 0) return error.AhciPortBusy;
    if (!stop(sata)) return error.AhciEngineDidNotStop;

    const physical = try pmm.allocate.single.allocatePage();
    defer if (safe_to_restore) pmm.free.single.freePage(physical);
    const page: *[sizes.PAGE_SIZE]u8 = @ptrFromInt(layout.PHYSMAP_BASE + physical);
    try ahci.command.prepare(page, physical, .Identify);
    @memset(page[wire.FIS_OFFSET..wire.TABLE_OFFSET], 0);
    const global = read(controller, values.GHC);
    write(controller, values.GHC, global & ~values.GLOBAL_INTERRUPT);
    write(sata, values.INTERRUPT_ENABLE, 0);
    write(sata, values.LIST, @intCast(physical));
    write(sata, values.LIST_HIGH, 0);
    write(sata, values.FIS, @intCast(physical + wire.FIS_OFFSET));
    write(sata, values.FIS_HIGH, 0);
    commandBits(command | values.BUS_MASTER);
    write(sata, values.COMMAND, read(sata, values.COMMAND) | values.RECEIVE_FIS);
    write(sata, values.COMMAND, read(sata, values.COMMAND) | values.START);

    const outcome = transfer(sata, physical, page, sector);
    if (!stop(sata)) {
        commandBits(command & ~values.BUS_MASTER);
        safe_to_restore = false;
        return error.AhciEngineDidNotStop;
    }
    write(sata, values.LIST, 0);
    write(sata, values.FIS, 0);
    commandBits(command);
    write(controller, values.GHC, global);
    try outcome;
    @memcpy(destination, page[wire.DATA_OFFSET..][0..wire.SECTOR_BYTES]);
}

fn transfer(sata: u64, physical: u64, page: *[sizes.PAGE_SIZE]u8, sector: u64) !void {
    try issue(sata, page);
    const payload = page[wire.DATA_OFFSET..][0..wire.SECTOR_BYTES];
    if (sector >= try ahci.command.capacity(payload)) return error.InvalidSector;
    try ahci.command.prepare(page, physical, .{ .Read = sector });
    try issue(sata, page);
}

fn issue(sata: u64, page: *const [sizes.PAGE_SIZE]u8) !void {
    if (read(sata, values.ISSUE) != 0 or read(sata, values.ACTIVE) != 0 or !waitClear(sata, values.TASK_FILE, values.TASK_BUSY))
        return error.AhciPortBusy;
    write(sata, values.SATA_ERROR, read(sata, values.SATA_ERROR));
    write(sata, values.INTERRUPT_STATUS, read(sata, values.INTERRUPT_STATUS));
    cpu.control.fenceMemory();
    write(sata, values.ISSUE, values.SLOT_ZERO);
    if (!waitClear(sata, values.ISSUE, values.SLOT_ZERO)) return error.AhciTransferTimeout;
    cpu.control.fenceMemory();
    if (read(sata, values.TASK_FILE) & values.TASK_ERROR != 0 or read(sata, values.INTERRUPT_STATUS) & values.TRANSFER_ERROR != 0)
        return error.AhciTransferFailed;
    if (std.mem.readInt(u32, page[values.TRANSFERRED_OFFSET..][0..4], .little) != wire.SECTOR_BYTES)
        return error.AhciShortTransfer;
}

fn stop(sata: u64) bool {
    write(sata, values.COMMAND, read(sata, values.COMMAND) & ~values.START);
    if (!waitClear(sata, values.COMMAND, values.RUNNING_COMMAND)) return false;
    write(sata, values.COMMAND, read(sata, values.COMMAND) & ~values.RECEIVE_FIS);
    return waitClear(sata, values.COMMAND, values.RUNNING_FIS);
}

fn selectPort(controller: u64) !u64 {
    const count = (read(controller, values.CAP) & values.PORT_NUMBER_MASK) + 1;
    if (count > (sizes.PAGE_SIZE - values.PORT_BASE) / values.PORT_STRIDE) return error.UnsupportedAhciController;
    const implemented = read(controller, values.PORTS);
    var selected: ?u64 = null;
    for (0..count) |index| {
        if (implemented & (@as(u32, 1) << @intCast(index)) == 0) continue;
        const sata = controller + values.PORT_BASE + index * values.PORT_STRIDE;
        const link = read(sata, values.LINK);
        if (link & values.LINK_PRESENT_MASK != values.LINK_PRESENT) continue;
        if (selected != null or link & values.LINK_ACTIVE_MASK != values.LINK_ACTIVE or read(sata, values.SIGNATURE) != values.ATA_SIGNATURE)
            return error.UnsupportedAhciPort;
        selected = sata;
    }
    return selected orelse error.AhciDiskMissing;
}

fn waitClear(base: u64, register: u64, mask: u32) bool {
    for (0..values.POLL_LIMIT) |_| {
        if (read(base, register) & mask == 0) return true;
        cpu.halt.pause();
    }
    return false;
}

fn pci(register: u32) u32 {
    port.writeLong(values.PCI_ADDRESS, values.ICH9_ADDRESS | register);
    return port.readLong(values.PCI_DATA);
}

fn commandBits(command: u16) void {
    port.writeLong(values.PCI_ADDRESS, values.ICH9_ADDRESS | values.PCI_COMMAND);
    port.writeWord(values.PCI_DATA, command);
}

fn read(base: u64, register: u64) u32 {
    const address: *const volatile u32 = @ptrFromInt(base + register);
    return address.*;
}

fn write(base: u64, register: u64, value: u32) void {
    const address: *volatile u32 = @ptrFromInt(base + register);
    address.* = value;
}
