//! Serve Installed Binary Launches And Initial Weaver Readiness

const std = @import("std");

const invoke = @import("personaasm").invoke;
const launch = @import("weaver").supervision.service.launch;
const letters = @import("shared").launch.constants.service.postman;
const limits = @import("shared").persona.constants.postman;
const protocol = @import("shared").pulse.constants.boot.weaver;
const request = @import("shared").launch.service.request;

const Header = @import("shared").persona.types.letter.Header;
const Status = @import("shared").persona.types.invocation.Status;

pub fn listen(pulse: u64) noreturn {
    var payload: [limits.MAX_PAYLOAD_BYTES]u8 = undefined;
    var header: Header = undefined;
    var endpoint: ?u64 = null;
    while (true) {
        const arrived = invoke.call(.Receive, @intFromPtr(&payload), payload.len, @intFromPtr(&header), 0);
        if (arrived.Status != @intFromEnum(Status.Success)) stop(arrived.Status);
        if (header.ReplyTicket == 0) continue;
        var child: u64 = 0;
        const kind = answer: {
            if (header.Length != arrived.Value or arrived.Value > payload.len) break :answer letters.REFUSED;
            const bytes = payload[0..@intCast(arrived.Value)];
            if (header.Type == protocol.QUERY and bytes.len == 0) break :answer protocol.READY;
            if (header.Type == letters.CONFIGURE and header.Sender == pulse and endpoint == null and bytes.len == @sizeOf(u64)) {
                const value = std.mem.readInt(u64, bytes[0..@sizeOf(u64)], .little);
                if (value == 0) break :answer letters.REFUSED;
                endpoint = value;
                break :answer letters.CONFIGURED;
            }
            const driver = header.Type == letters.DRIVER;
            if (driver and header.Sender != pulse) break :answer letters.REFUSED;
            if (!driver and header.Type != letters.LAUNCH) break :answer protocol.UNSUPPORTED;
            const afs = endpoint orelse break :answer letters.REFUSED;
            const input = if (driver) (request.decodeAttached(bytes) orelse break :answer letters.REFUSED).Binary else request.decode(bytes) orelse break :answer letters.REFUSED;
            child = launch.start(afs, input, header.ReplyTicket, driver) catch |failure|
                break :answer if (failure == error.BinaryMissing or failure == error.LibraryNotFound) letters.MISSING else letters.REFUSED;
            if (driver) continue;
            break :answer letters.STARTED;
        };
        const replied = invoke.call(.Reply, header.ReplyTicket, if (child == 0) 0 else @intFromPtr(&child), if (child == 0) 0 else @sizeOf(u64), kind);
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
