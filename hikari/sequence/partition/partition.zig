//! Hikari AFS Partition Locator

const std = @import("std");

const efi = @import("hikari").efi;
const errors = @import("hikari").sequence.errors.partition.discovery;
const parser = @import("hikari").disk.types.parser;
const types = @import("hikari").sequence.types.partition.discovery;

const Discovery = types.Discovery;
const DiscoveryError = errors.DiscoveryError;
const PartitionInfo = types.PartitionInfo;
const status = efi.constants.status.codes;

pub fn findAfsPartition(state: *Discovery) DiscoveryError!?PartitionInfo {
    if (!state.Handles.isEmpty() or !state.Parser.Scratch.Pool.isEmpty()) return DiscoveryError.ReleaseFailed;
    const services = state.Parser.BootServices;
    var handle_count: usize = 0;
    var handles: ?[*]efi.types.base.Handle = null;
    if (services.LocateHandleBuffer(.ByProtocol, &efi.constants.guids.BLOCK_IO_PROTOCOL, null, &handle_count, @ptrCast(&handles)) != status.SUCCESS) return null;
    const bytes = std.math.mul(usize, handle_count, @sizeOf(efi.types.base.Handle)) catch {
        state.Handles.Untrusted = true;
        return DiscoveryError.InvalidFirmwareReply;
    };
    const raw: ?[*]align(8) u8 = if (handles) |list| @ptrCast(list) else null;
    if (!efi.buffer.recordPool(&state.Handles, raw, bytes)) return DiscoveryError.InvalidFirmwareReply;

    const found = try scan(state, handles.?[0..handle_count]);
    if (!efi.buffer.releasePool(services, &state.Handles)) return DiscoveryError.ReleaseFailed;
    return found;
}

pub fn deinitialize(state: *Discovery) bool {
    const parser_released = state.Parser.deinitialize();
    const handles_released = efi.buffer.releasePool(state.Parser.BootServices, &state.Handles);
    return parser_released and handles_released;
}

fn scan(state: *Discovery, handles: []const efi.types.base.Handle) DiscoveryError!?PartitionInfo {
    const services = state.Parser.BootServices;
    for (handles) |handle| {
        var interface: ?*anyopaque = null;
        if (efi.status.isError(services.HandleProtocol(handle, &efi.constants.guids.BLOCK_IO_PROTOCOL, &interface))) continue;
        const protocol: *efi.types.protocols.block.BlockIoProtocol = @ptrCast(@alignCast(interface orelse continue));
        if (protocol.Media.LogicalPartition) continue;

        const parsed = if (state.Parser.initialize(protocol)) |_| true else |failure| rejected: {
            if (failure == error.ReleaseFailed) return DiscoveryError.ReleaseFailed;
            break :rejected false;
        };
        const found = if (parsed) match(&state.Parser) else null;
        if (!state.Parser.deinitialize()) return DiscoveryError.ReleaseFailed;
        if (found) |info| return info;
    }
    return null;
}

fn match(table: *const parser.Parser) ?PartitionInfo {
    if (table.Media.LogicalPartition or !table.Media.isCurrent()) return null;
    const partition = table.findPartitionByType(efi.constants.guids.GPT_PARTITION_TYPE_AKIBA_AFS) orelse return null;
    return .{ .Media = table.Media, .StartLBA = partition.StartingLBA, .EndLBA = partition.EndingLBA };
}
