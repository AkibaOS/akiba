//! Resident Pulse Mailbox And Bootstrap Status Replies

const invoke = @import("personaasm").invoke;
const limits = @import("shared").persona.constants.postman;
const protocol = @import("shared").pulse.constants.status;

const Header = @import("shared").persona.types.letter.Header;
const Status = @import("shared").persona.types.invocation.Status;

pub fn listen() noreturn {
    var payload: [limits.MAX_PAYLOAD_BYTES]u8 = undefined;
    var header: Header = undefined;
    while (true) {
        const arrived = invoke.call(.Receive, @intFromPtr(&payload), payload.len, @intFromPtr(&header), 0);
        if (arrived.Status != @intFromEnum(Status.Success)) stop(arrived.Status);
        if (header.ReplyTicket == 0) continue;
        const status = if (header.Type == protocol.QUERY and header.Length == 0 and arrived.Value == 0)
            protocol.READY
        else
            protocol.UNSUPPORTED;
        const replied = invoke.call(.Reply, header.ReplyTicket, 0, 0, status);
        switch (replied.Status) {
            @intFromEnum(Status.Success), @intFromEnum(Status.PeerGone), @intFromEnum(Status.InvalidReply) => {},
            else => stop(replied.Status),
        }
    }
}

pub fn stop(code: u64) noreturn {
    _ = invoke.call(.Exit, code, 0, 0, 0);
    @trap();
}
