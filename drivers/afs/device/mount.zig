//! Mount The Boot Partition Through The AHCI Driver Inbox

const std = @import("std");

const afs = @import("shared").afs;
const install = @import("shared").location.strings.installed.paths;
const invoke = @import("personaasm").invoke;
const protocol = @import("shared").ahci.constants.device.postman;
const record = @import("shared").launch.constants.startup.record;
const startup = @import("shared").launch.startup;
const wire = @import("shared").ahci.constants.command.dma;

const Call = @import("shared").persona.types.call.Call;
const Header = @import("shared").persona.types.letter.Header;
const Mount = afs.types.service.mount.Mount;
const SectorVolume = afs.types.read.sectors.SectorVolume;
const Status = @import("shared").persona.types.invocation.Status;

pub fn parameters(address: u64) !Mount {
    if (address == 0) return error.InvalidStartup;
    const bytes: [*]const u8 = @ptrFromInt(address);
    _ = try startup.decode(bytes[0..record.HEADER_BYTES], afs.constants.sizes.DEFAULT_CELL_SIZE);
    const identity = std.mem.readInt(u64, bytes[record.IDENTITY_LENGTH..record.PARAMETER_LENGTH], .little);
    const size = std.mem.readInt(u64, bytes[record.PARAMETER_LENGTH..record.HEADER_BYTES], .little);
    const begin = record.HEADER_BYTES;
    const base = begin + install.FLAT_AFS_PATH.len;
    if (identity != install.FLAT_AFS_PATH.len or size != @sizeOf(Mount) or !std.mem.eql(u8, bytes[begin..base], install.FLAT_AFS_PATH))
        return error.InvalidStartup;
    const result = std.mem.bytesToValue(Mount, bytes[base..][0..@sizeOf(Mount)]);
    if (result.PulseID == 0 or result.WeaverID == 0 or result.DiskDriverID == 0 or result.LastSector == 0) return error.InvalidStartup;
    return result;
}

pub fn open(settings: *Mount, scratch: []u8) !SectorVolume {
    return afs.read.sectors.open(.{
        .Context = settings,
        .Read = sector,
        .BlockBytes = wire.SECTOR_BYTES,
        .LastLBA = settings.LastSector,
    }, 0, settings.LastSector, scratch);
}

fn sector(context: *anyopaque, index: u64, output: []u8) !void {
    const settings: *const Mount = @ptrCast(@alignCast(context));
    if (index > settings.LastSector or output.len != wire.SECTOR_BYTES) return error.InvalidSector;
    var request: [@sizeOf(u64)]u8 = undefined;
    std.mem.writeInt(u64, &request, index, .little);
    var header: Header = undefined;
    const descriptor: Call = .{
        .Destination = settings.DiskDriverID,
        .Type = protocol.READ,
        .Request = @intFromPtr(&request),
        .RequestLength = request.len,
        .Reply = @intFromPtr(output.ptr),
        .ReplyCapacity = output.len,
        .Metadata = @intFromPtr(&header),
    };
    const response = invoke.call(.Call, @intFromPtr(&descriptor), 0, 0, 0);
    if (response.Status != @intFromEnum(Status.Success) or response.Value != output.len or
        header.Sender != settings.DiskDriverID or header.Type != protocol.SECTOR or
        header.Length != output.len or header.ReplyTicket != 0) return error.ReadFailed;
}
