//! Start And Verify The First Resident Weaver

const inbox = @import("pulse").supervision.inbox;
const invoke = @import("personaasm").invoke;
const status = @import("shared").pulse.constants.boot.weaver;

const Call = @import("shared").persona.types.call.Call;
const Header = @import("shared").persona.types.letter.Header;
const Operation = @import("shared").pulse.types.boot.control.Operation;
const Status = @import("shared").persona.types.invocation.Status;

pub fn start() void {
    const launched = invoke.call(.BootstrapWeaver, @intFromEnum(Operation.Start), 0, 0, 0);
    if (launched.Status != @intFromEnum(Status.Success)) inbox.stop(launched.Status);
    if (launched.Value == 0) inbox.stop(@intFromEnum(Status.InvalidState));
    var header: Header = undefined;
    const query: Call = .{
        .Destination = launched.Value,
        .Type = status.QUERY,
        .Request = 0,
        .RequestLength = 0,
        .Reply = 0,
        .ReplyCapacity = 0,
        .Metadata = @intFromPtr(&header),
    };
    const replied = invoke.call(.Call, @intFromPtr(&query), 0, 0, 0);
    if (replied.Status != @intFromEnum(Status.Success)) inbox.stop(replied.Status);
    if (replied.Value != 0 or header.Sender != launched.Value or header.Type != status.READY or
        header.Length != 0 or header.ReplyTicket != 0) inbox.stop(@intFromEnum(Status.InvalidReply));
    const confirmation = invoke.call(.BootstrapWeaver, @intFromEnum(Operation.Confirm), launched.Value, 0, 0);
    if (confirmation.Status != @intFromEnum(Status.Success)) inbox.stop(confirmation.Status);
}
