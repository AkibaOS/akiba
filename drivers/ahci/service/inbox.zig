//! Serve Scoped Read Only Sector Requests From Pulse

const std = @import("std");

const disk = @import("ahci").device.disk;
const invoke = @import("personaasm").invoke;
const limits = @import("shared").persona.constants.postman;
const protocol = @import("shared").ahci.constants.device.postman;
const service = @import("shared").pulse.constants.supervision.protocol;
const wire = @import("shared").ahci.constants.command.dma;

const Description = @import("shared").ahci.types.device.invocation.Description;
const Header = @import("shared").persona.types.letter.Header;
const Status = @import("shared").persona.types.invocation.Status;

pub fn listen(description: Description) noreturn {
    var request: [limits.MAX_PAYLOAD_BYTES]u8 = undefined;
    var output: [wire.SECTOR_BYTES]u8 = undefined;
    var header: Header = undefined;
    while (true) {
        const arrived = invoke.call(.Receive, @intFromPtr(&request), request.len, @intFromPtr(&header), 0);
        if (arrived.Status != @intFromEnum(Status.Success)) stop(arrived.Status);
        if (header.ReplyTicket == 0) continue;
        const accepted = (header.Sender == description.PulseID or disk.accepts(header.Sender)) and header.Type == protocol.READ and
            header.Length == @sizeOf(u64) and arrived.Value == @sizeOf(u64) and
            read(description, std.mem.readInt(u64, request[0..@sizeOf(u64)], .little), &output);
        const supervised = header.Sender == description.PulseID and header.Length == 0 and arrived.Value == 0;
        const closing = supervised and header.Type == service.SERVICE_STOP;
        const kind = if (accepted) protocol.SECTOR else if (closing) service.SERVICE_STOPPED else if (supervised and header.Type == service.SERVICE_QUERY) service.SERVICE_READY else protocol.REFUSED;
        const reply = invoke.call(.Reply, header.ReplyTicket, if (accepted) @intFromPtr(&output) else 0, if (accepted) output.len else 0, kind);
        switch (reply.Status) {
            @intFromEnum(Status.Success), @intFromEnum(Status.PeerGone), @intFromEnum(Status.InvalidReply) => {},
            else => stop(reply.Status),
        }
        if (closing) stop(0);
    }
}

fn read(description: Description, sector: u64, output: []u8) bool {
    const volume = description.Volume;
    if (sector > volume.LastLBA - volume.FirstLBA) return false;
    disk.readSector(volume.FirstLBA + sector, output) catch return false;
    return true;
}

pub fn stop(code: u64) noreturn {
    _ = invoke.call(.Exit, code, 0, 0, 0);
    @trap();
}
