//! Issue And Validate The Two Diagnostic ATA Commands

const std = @import("std");

const ahci = @import("shared").ahci;
const cpu = @import("asm").cpu;
const registers = @import("tests").guest.ahci.registers;
const sizes = @import("common").constants.memory.sizes;
const values = @import("tests").guest.constants.ahci.registers;

const CommandError = ahci.errors.command.transfer.CommandError;
const ProbeError = @import("tests").guest.errors.ahci.transfer.ProbeError;
const wire = ahci.constants.command.dma;

pub fn read(sata: u64, physical: u64, page: *[sizes.PAGE_SIZE]u8, sector: u64) !void {
    try issue(sata, page);
    const payload = page[wire.DATA_OFFSET..][0..wire.SECTOR_BYTES];
    if (sector >= try ahci.command.identify.capacity(payload)) return CommandError.InvalidSector;
    try ahci.command.encode.prepare(page, physical, .{ .Read = sector });
    try issue(sata, page);
}

fn issue(sata: u64, page: *const [sizes.PAGE_SIZE]u8) !void {
    if (registers.read(sata, values.ISSUE) != 0 or registers.read(sata, values.ACTIVE) != 0 or !registers.waitClear(sata, values.TASK_FILE, values.TASK_BUSY))
        return ProbeError.AhciPortBusy;
    registers.write(sata, values.SATA_ERROR, registers.read(sata, values.SATA_ERROR));
    registers.write(sata, values.INTERRUPT_STATUS, registers.read(sata, values.INTERRUPT_STATUS));
    cpu.control.fenceMemory();
    registers.write(sata, values.ISSUE, values.SLOT_ZERO);
    if (!registers.waitClear(sata, values.ISSUE, values.SLOT_ZERO)) return ProbeError.AhciTransferTimeout;
    cpu.control.fenceMemory();
    if (registers.read(sata, values.TASK_FILE) & values.TASK_ERROR != 0 or registers.read(sata, values.INTERRUPT_STATUS) & values.TRANSFER_ERROR != 0)
        return ProbeError.AhciTransferFailed;
    if (std.mem.readInt(u32, page[wire.TRANSFERRED_OFFSET..][0..4], .little) != wire.SECTOR_BYTES)
        return ProbeError.AhciShortTransfer;
}
