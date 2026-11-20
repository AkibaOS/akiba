//! Issue And Validate Bootstrap ATA Reads

const std = @import("std");

const ahci = @import("shared").ahci;
const cpu = @import("asm").cpu;
const registers = @import("mirai").bootstrap.storage.registers;
const sizes = @import("common").constants.memory.sizes;
const values = @import("mirai").bootstrap.constants.storage.registers;

const CommandError = ahci.errors.command.transfer.CommandError;
const Disk = @import("mirai").bootstrap.types.storage.disk.Disk;
const Source = @import("shared").storage.types.sector.Source;
const StorageError = @import("mirai").bootstrap.errors.storage.read.StorageError;
const wire = ahci.constants.command.dma;

pub fn identify(port: u64, page: *const [sizes.PAGE_SIZE]u8) !u64 {
    try requireIdle(port);
    try issue(port, page);
    return ahci.command.identify.capacity(page[wire.DATA_OFFSET..][0..wire.SECTOR_BYTES]);
}

pub fn source(disk: *Disk) Source {
    return .{ .Context = disk, .Read = read, .BlockBytes = wire.SECTOR_BYTES, .LastLBA = disk.Sectors - 1 };
}

fn read(context: *anyopaque, lba: u64, block: []u8) !void {
    const disk: *const Disk = @ptrCast(@alignCast(context));
    if (block.len != wire.SECTOR_BYTES) return StorageError.InvalidSectorBuffer;
    if (lba >= disk.Sectors) return CommandError.InvalidSector;
    try requireIdle(disk.Port);
    try ahci.command.encode.prepare(disk.Page, disk.Physical, .{ .Read = lba });
    try issue(disk.Port, disk.Page);
    @memcpy(block, disk.Page[wire.DATA_OFFSET..][0..wire.SECTOR_BYTES]);
}

fn requireIdle(port: u64) StorageError!void {
    if (registers.read(port, values.ISSUE) != 0 or registers.read(port, values.ACTIVE) != 0 or
        !registers.waitClear(port, values.TASK_FILE, values.TASK_BUSY)) return StorageError.AhciPortBusy;
}

fn issue(port: u64, page: *const [sizes.PAGE_SIZE]u8) StorageError!void {
    registers.write(port, values.SATA_ERROR, registers.read(port, values.SATA_ERROR));
    registers.write(port, values.INTERRUPT_STATUS, registers.read(port, values.INTERRUPT_STATUS));
    cpu.control.fenceMemory();
    registers.write(port, values.ISSUE, values.SLOT_ZERO);
    if (!registers.waitClear(port, values.ISSUE, values.SLOT_ZERO)) return StorageError.AhciTransferTimeout;
    cpu.control.fenceMemory();
    if (registers.read(port, values.TASK_FILE) & values.TASK_ERROR != 0 or registers.read(port, values.INTERRUPT_STATUS) & values.TRANSFER_ERROR != 0)
        return StorageError.AhciTransferFailed;
    if (std.mem.readInt(u32, page[wire.TRANSFERRED_OFFSET..][0..@sizeOf(u32)], .little) != wire.SECTOR_BYTES)
        return StorageError.AhciShortTransfer;
}
