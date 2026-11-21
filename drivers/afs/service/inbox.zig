//! Serve AFS Requests From The Initial System Owner

const invoke = @import("personaasm").invoke;
const letters = @import("shared").afs.constants.service.postman;
const limits = @import("shared").persona.constants.postman;
const request = @import("afs").service.request;

const Catalog = @import("shared").afs.types.reader.Catalog;
const Header = @import("shared").persona.types.letter.Header;
const Reply = @import("afs").types.service.reply.Reply;
const Status = @import("shared").persona.types.invocation.Status;

pub fn listen(catalog: *const Catalog, pulse: u64, scratch: []u8) noreturn {
    var incoming: [limits.MAX_PAYLOAD_BYTES]u8 = undefined;
    var output: [limits.MAX_PAYLOAD_BYTES]u8 = undefined;
    var header: Header = undefined;
    while (true) {
        const arrived = invoke.call(.Receive, @intFromPtr(&incoming), incoming.len, @intFromPtr(&header), 0);
        if (arrived.Status != @intFromEnum(Status.Success)) stop(arrived.Status);
        if (header.ReplyTicket == 0) continue;
        const response: Reply = if (header.Sender == pulse and arrived.Value == header.Length and arrived.Value <= incoming.len)
            request.respond(catalog, header.Type, incoming[0..@intCast(arrived.Value)], &output, scratch)
        else
            .{ .Kind = letters.REFUSED };
        const replied = invoke.call(.Reply, header.ReplyTicket, if (response.Length == 0) 0 else @intFromPtr(&output), response.Length, response.Kind);
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
