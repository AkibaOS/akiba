//! Serve Mode Queries And Complete Present Requests From Pulse

const blit = @import("display").raster.blit;
const invoke = @import("personaasm").invoke;
const limits = @import("shared").persona.constants.postman;
const protocol = @import("shared").display.constants.postman;
const service = @import("shared").pulse.constants.supervision.protocol;

const Header = @import("shared").persona.types.letter.Header;
const Mode = @import("shared").display.types.mode.Mode;
const Operation = @import("shared").device.types.operation.Operation;
const Status = @import("shared").persona.types.invocation.Status;

pub fn listen(supervisor: u64) noreturn {
    const assignment = invoke.call(.Device, @intFromEnum(Operation.Lease), 0, 0, 0);
    if (assignment.Status != @intFromEnum(Status.Success)) stop(assignment.Status);
    var mode: ?Mode = null;
    var payload: [limits.MAX_PAYLOAD_BYTES]u8 = undefined;
    var header: Header = undefined;
    while (true) {
        const received = invoke.call(.Receive, @intFromPtr(&payload), payload.len, @intFromPtr(&header), 0);
        if (received.Status != @intFromEnum(Status.Success)) stop(received.Status);
        if (header.ReplyTicket == 0) continue;
        var kind = service.REFUSED;
        var output_address: u64 = 0;
        var output_length: u64 = 0;
        var closing = false;
        if (header.Sender == supervisor and header.Length == received.Value and received.Value <= payload.len) {
            const bytes = payload[0..@intCast(received.Value)];
            switch (header.Type) {
                service.SERVICE_QUERY => if (bytes.len == 0) {
                    mode = describe(assignment.Value);
                    if (mode != null) kind = service.SERVICE_READY;
                },
                service.SERVICE_STOP => if (bytes.len == 0) {
                    kind = service.SERVICE_STOPPED;
                    closing = true;
                },
                protocol.QUERY => if (bytes.len == 0) {
                    if (mode) |*current| {
                        kind = protocol.MODE;
                        output_address = @intFromPtr(current);
                        output_length = @sizeOf(Mode);
                    }
                },
                protocol.PRESENT => if (mode) |current| {
                    if (blit.present(assignment.Value, current, bytes)) kind = protocol.PRESENTED;
                },
                else => {},
            }
        }
        const reply = invoke.call(.Reply, header.ReplyTicket, output_address, output_length, kind);
        switch (reply.Status) {
            @intFromEnum(Status.Success), @intFromEnum(Status.PeerGone), @intFromEnum(Status.InvalidReply) => {},
            else => stop(reply.Status),
        }
        if (closing) stop(0);
    }
}

fn describe(handle: u64) ?Mode {
    var mode: Mode = undefined;
    const result = invoke.call(.Device, @intFromEnum(Operation.SurfaceDescribe), handle, @intFromPtr(&mode), 0);
    return if (result.Status == @intFromEnum(Status.Success) and mode.isValid()) mode else null;
}

pub fn stop(code: u64) noreturn {
    _ = invoke.call(.Exit, code, 0, 0, 0);
    @trap();
}
