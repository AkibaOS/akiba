//! Issue And Validate Diagnostic ATA Commands

const std = @import("std");

const ahci = @import("shared").ahci;
const cpu = @import("asm").cpu;
const registers = @import("tests").guest.ahci.registers;
const sizes = @import("common").constants.memory.sizes;
const values = @import("tests").guest.constants.ahci.registers;

const CommandError = ahci.errors.command.transfer.CommandError;
const Disk = @import("tests").guest.types.ahci.disk.Disk;
const ProbeError = @import("tests").guest.errors.ahci.transfer.ProbeError;
const wire = ahci.constants.command.dma;

pub fn identify(port: u64, page: *const [sizes.PAGE_SIZE]u8) !u64 {
    try requireIdle(port);
    try issue(port, page);
    return ahci.command.identify.capacity(page[wire.DATA_OFFSET..][0..wire.SECTOR_BYTES]);
}

pub fn read(disk: *const Disk, lba: u64, block: *[wire.SECTOR_BYTES]u8) !void {
    if (lba >= disk.Sectors) return CommandError.InvalidSector;
    try requireIdle(disk.Port);
    try ahci.command.encode.prepare(disk.Page, disk.Physical, .{ .Read = lba });
    try issue(disk.Port, disk.Page);
    @memcpy(block, disk.Page[wire.DATA_OFFSET..][0..wire.SECTOR_BYTES]);
}

fn requireIdle(port: u64) ProbeError!void {
    if (registers.read(port, values.ISSUE) != 0 or registers.read(port, values.ACTIVE) != 0 or
        !registers.waitClear(port, values.TASK_FILE, values.TASK_BUSY)) return ProbeError.AhciPortBusy;
}

fn issue(port: u64, page: *const [sizes.PAGE_SIZE]u8) ProbeError!void {
    registers.write(port, values.SATA_ERROR, registers.read(port, values.SATA_ERROR));
    registers.write(port, values.INTERRUPT_STATUS, registers.read(port, values.INTERRUPT_STATUS));
    cpu.control.fenceMemory();
    registers.write(port, values.ISSUE, values.SLOT_ZERO);
    if (!registers.waitClear(port, values.ISSUE, values.SLOT_ZERO)) return ProbeError.AhciTransferTimeout;
    cpu.control.fenceMemory();
    if (registers.read(port, values.TASK_FILE) & values.TASK_ERROR != 0 or registers.read(port, values.INTERRUPT_STATUS) & values.TRANSFER_ERROR != 0)
        return ProbeError.AhciTransferFailed;
    if (std.mem.readInt(u32, page[wire.TRANSFERRED_OFFSET..][0..@sizeOf(u32)], .little) != wire.SECTOR_BYTES)
        return ProbeError.AhciShortTransfer;
}
