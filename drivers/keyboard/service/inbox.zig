//! Serve Normalized Input To The Supervising Kata

const std = @import("std");

const decode = @import("keyboard").input.decode;
const invoke = @import("personaasm").invoke;
const limits = @import("shared").persona.constants.postman;
const protocol = @import("shared").keyboard.constants.postman;
const queue = @import("keyboard").service.queue;
const service = @import("shared").pulse.constants.supervision.protocol;

const Event = @import("shared").keyboard.types.event.Event;
const Header = @import("shared").persona.types.letter.Header;
const Operation = @import("shared").keyboard.types.operation.Operation;
const Queue = @import("keyboard").types.service.queue.Queue;
const State = @import("keyboard").types.input.state.State;
const Status = @import("shared").persona.types.invocation.Status;

pub fn listen(supervisor: u64) noreturn {
    var pending: Queue = .{};
    var decoder: State = .{};
    var active = false;
    var payload: [limits.MAX_PAYLOAD_BYTES]u8 = undefined;
    var header: Header = undefined;
    while (true) {
        if (active) {
            const next = invoke.call(.Keyboard, @intFromEnum(Operation.Next), 0, 0, 0);
            switch (next.Status) {
                @intFromEnum(Status.Success) => {
                    if (next.Value > std.math.maxInt(u8)) stop(@intFromEnum(Status.InvalidState));
                    if (decode.feed(&decoder, @intCast(next.Value))) |event| queue.push(&pending, event);
                    continue;
                },
                @intFromEnum(Status.InputLost) => {
                    decoder = .{};
                    queue.lost(&pending);
                    continue;
                },
                @intFromEnum(Status.WouldBlock) => {},
                else => stop(next.Status),
            }
        }
        const arrived = invoke.call(.Receive, @intFromPtr(&payload), payload.len, @intFromPtr(&header), 0);
        if (arrived.Status != @intFromEnum(Status.Success)) stop(arrived.Status);
        if (header.ReplyTicket == 0) continue;
        var kind = service.REFUSED;
        var event: ?Event = null;
        var closing = false;
        if (header.Sender == supervisor and header.Length == 0 and arrived.Value == 0) {
            switch (header.Type) {
                service.SERVICE_QUERY => {
                    const result = invoke.call(.Keyboard, @intFromEnum(Operation.Check), 0, 0, 0);
                    if (result.Status == @intFromEnum(Status.Success)) {
                        active = true;
                        kind = service.SERVICE_READY;
                    }
                },
                service.SERVICE_STOP => {
                    kind = service.SERVICE_STOPPED;
                    closing = true;
                },
                protocol.READ => if (active) {
                    if (pending.Lost) {
                        pending.Lost = false;
                        kind = protocol.LOST;
                    } else {
                        event = queue.take(&pending);
                        kind = if (event != null) protocol.EVENT else protocol.EMPTY;
                    }
                },
                else => {},
            }
        }
        const reply = if (event) |*value| invoke.call(.Reply, header.ReplyTicket, @intFromPtr(value), @sizeOf(Event), kind) else invoke.call(.Reply, header.ReplyTicket, 0, 0, kind);
        switch (reply.Status) {
            @intFromEnum(Status.Success), @intFromEnum(Status.PeerGone), @intFromEnum(Status.InvalidReply) => {},
            else => stop(reply.Status),
        }
        if (closing) stop(0);
    }
}

pub fn stop(code: u64) noreturn {
    _ = invoke.call(.Exit, code, 0, 0, 0);
    @trap();
}
