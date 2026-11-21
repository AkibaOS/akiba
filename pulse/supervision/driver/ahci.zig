//! Start And Verify The Initial AHCI Driver Through Postman

const std = @import("std");

const invoke = @import("personaasm").invoke;
const magic = @import("shared").afs.constants.magic;
const protocol = @import("shared").ahci.constants.device.postman;
const pulse = @import("pulse").supervision.inbox;
const wire = @import("shared").ahci.constants.command.dma;

const Call = @import("shared").persona.types.call.Call;
const Header = @import("shared").persona.types.letter.Header;
const Operation = @import("shared").pulse.types.boot.driver.Operation;
const Status = @import("shared").persona.types.invocation.Status;

pub fn start() void {
    const launched = invoke.call(.BootstrapDriver, @intFromEnum(Operation.StartAhci), 0, 0, 0);
    if (launched.Status != @intFromEnum(Status.Success)) pulse.stop(launched.Status);
    if (launched.Value == 0) pulse.stop(@intFromEnum(Status.InvalidState));
    if (!firstSector(launched.Value)) pulse.stop(@intFromEnum(Status.InvalidReply));
    const confirmed = invoke.call(.BootstrapDriver, @intFromEnum(Operation.ConfirmAhci), launched.Value, 0, 0);
    if (confirmed.Status != @intFromEnum(Status.Success)) pulse.stop(confirmed.Status);
}

fn firstSector(driver: u64) bool {
    const sector = [_]u8{0} ** @sizeOf(u64);
    var bytes: [wire.SECTOR_BYTES]u8 = undefined;
    var header: Header = undefined;
    const request: Call = .{
        .Destination = driver,
        .Type = protocol.READ,
        .Request = @intFromPtr(&sector),
        .RequestLength = sector.len,
        .Reply = @intFromPtr(&bytes),
        .ReplyCapacity = bytes.len,
        .Metadata = @intFromPtr(&header),
    };
    const received = invoke.call(.Call, @intFromPtr(&request), 0, 0, 0);
    return received.Status == @intFromEnum(Status.Success) and received.Value == bytes.len and
        header.Sender == driver and header.Type == protocol.SECTOR and header.Length == bytes.len and header.ReplyTicket == 0 and
        std.mem.readInt(u64, bytes[0..@sizeOf(u64)], .little) == magic.SIGNATURE;
}
