//! Serve Scoped Read Only Sector Requests From Pulse

const std = @import("std");

const disk = @import("ahci").device.disk;
const invoke = @import("personaasm").invoke;
const limits = @import("shared").persona.constants.postman;
const protocol = @import("shared").ahci.constants.device.postman;
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
        const reply = if (accepted)
            invoke.call(.Reply, header.ReplyTicket, @intFromPtr(&output), output.len, protocol.SECTOR)
        else
            invoke.call(.Reply, header.ReplyTicket, 0, 0, protocol.REFUSED);
        switch (reply.Status) {
            @intFromEnum(Status.Success), @intFromEnum(Status.PeerGone), @intFromEnum(Status.InvalidReply) => {},
            else => stop(reply.Status),
        }
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
