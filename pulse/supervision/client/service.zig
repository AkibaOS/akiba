//! Bound Service Readiness And Shutdown By Actual Replies And Outcomes

const invoke = @import("personaasm").invoke;
const protocol = @import("shared").pulse.constants.supervision.protocol;

const Call = @import("shared").persona.types.call.Call;
const Header = @import("shared").persona.types.letter.Header;
const Record = @import("shared").persona.types.completion.Record;
const Status = @import("shared").persona.types.invocation.Status;

pub fn ready(identifier: u64, ticks: u64) bool {
    return exchange(identifier, ticks, protocol.SERVICE_QUERY, protocol.SERVICE_READY);
}

pub fn stop(identifier: u64, ticks: u64) !void {
    if (!observed(identifier)) {
        const acknowledged = exchange(identifier, ticks, protocol.SERVICE_STOP, protocol.SERVICE_STOPPED);
        if (!acknowledged or !wait(identifier, ticks)) {
            try terminate(identifier);
            if (!wait(identifier, ticks)) return error.ShutdownFailed;
        }
    }
    try collect(identifier);
}

pub fn terminate(identifier: u64) !void {
    const result = invoke.call(.StopChild, identifier, 0, 0, 0);
    if (result.Status != @intFromEnum(Status.Success) and result.Status != @intFromEnum(Status.InvalidTarget)) return error.ShutdownFailed;
}

pub fn collect(identifier: u64) !void {
    var outcome: Record = undefined;
    const result = invoke.call(.CollectCompletion, identifier, @intFromPtr(&outcome), @sizeOf(Record), 0);
    if (result.Status != @intFromEnum(Status.InvalidTarget) and
        (result.Status != @intFromEnum(Status.Success) or result.Value != @sizeOf(Record))) return error.CollectionFailed;
}

pub fn observed(identifier: u64) bool {
    var outcome: Record = undefined;
    const result = invoke.call(.ObserveCompletion, identifier, @intFromPtr(&outcome), @sizeOf(Record), 0);
    return (result.Status == @intFromEnum(Status.Success) and result.Value == @sizeOf(Record)) or
        result.Status == @intFromEnum(Status.InvalidTarget);
}

pub fn wait(identifier: u64, ticks: u64) bool {
    var outcome: Record = undefined;
    const result = invoke.call(.WaitCompletionTimed, identifier, @intFromPtr(&outcome), @sizeOf(Record), ticks);
    return (result.Status == @intFromEnum(Status.Success) and result.Value == @sizeOf(Record)) or
        result.Status == @intFromEnum(Status.InvalidTarget);
}

fn exchange(identifier: u64, ticks: u64, request: u64, expected: u64) bool {
    var header: Header = undefined;
    const descriptor: Call = .{
        .Destination = identifier,
        .Type = request,
        .Request = 0,
        .RequestLength = 0,
        .Reply = 0,
        .ReplyCapacity = 0,
        .Metadata = @intFromPtr(&header),
    };
    const result = invoke.call(.CallTimed, @intFromPtr(&descriptor), ticks, 0, 0);
    return result.Status == @intFromEnum(Status.Success) and result.Value == 0 and header.Sender == identifier and
        header.Type == expected and header.Length == 0 and header.ReplyTicket == 0;
}
