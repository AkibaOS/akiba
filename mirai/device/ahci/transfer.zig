//! Complete One Read Only AHCI Command In Owned Memory

const std = @import("std");

const ahci = @import("shared").ahci;
const cpu = @import("asm").cpu;
const registers = @import("mirai").device.ahci.registers;
const values = @import("mirai").device.constants.ahci.registers;

const CommandError = ahci.errors.command.transfer.CommandError;
const Operation = ahci.types.command.operation.Operation;
const Slot = @import("mirai").device.types.ahci.slot.Slot;
const TransferError = @import("mirai").device.errors.ahci.transfer.TransferError;
const wire = ahci.constants.command.dma;

pub fn execute(slot: Slot, operation: Operation, output: []u8) (CommandError || TransferError)!void {
    if (output.len != wire.SECTOR_BYTES) return TransferError.InvalidSectorBuffer;
    const port = slot.Port;
    if (registers.read(port, values.ISSUE) != 0 or registers.read(port, values.ACTIVE) != 0 or
        !registers.waitClear(port, values.TASK_FILE, values.TASK_BUSY)) return TransferError.AhciPortBusy;
    try ahci.command.encode.prepare(slot.Page, slot.Physical, operation);
    try issue(slot);
    @memcpy(output, slot.Page[wire.DATA_OFFSET..][0..wire.SECTOR_BYTES]);
}

fn issue(slot: Slot) TransferError!void {
    const port = slot.Port;
    registers.write(port, values.SATA_ERROR, registers.read(port, values.SATA_ERROR));
    registers.write(port, values.INTERRUPT_STATUS, registers.read(port, values.INTERRUPT_STATUS));
    cpu.control.fenceMemory();
    registers.write(port, values.ISSUE, values.SLOT_ZERO);
    if (!registers.waitClear(port, values.ISSUE, values.SLOT_ZERO)) return TransferError.AhciTransferTimeout;
    cpu.control.fenceMemory();
    if (registers.read(port, values.TASK_FILE) & values.TASK_ERROR != 0 or registers.read(port, values.INTERRUPT_STATUS) & values.TRANSFER_ERROR != 0)
        return TransferError.AhciTransferFailed;
    if (std.mem.readInt(u32, slot.Page[wire.TRANSFERRED_OFFSET..][0..@sizeOf(u32)], .little) != wire.SECTOR_BYTES)
        return TransferError.AhciShortTransfer;
}
