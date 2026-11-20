//! Real Hikari Acquisition Of Writer Produced Multi Level AFS

const std = @import("std");

const abort = @import("hikari").sequence.cleanup;
const afs = @import("shared").afs;
const base = @import("hikari").efi.types.base;
const claimtypes = @import("hikari").sequence.types.cleanup.claims;
const codes = @import("hikari").efi.constants.status.codes;
const convention = @import("hikari").efi.constants.convention;
const efi = @import("hikari").efi;
const inputs = @import("tests").fixtures.constants.storage;
const labels = @import("tests").fixtures.strings.storage;
const locator = @import("hikari").sequence.partition;
const output = @import("tests").efi.firmware.run;
const partition = @import("hikari").sequence.types.partition.discovery;
const readers = @import("hikari").fs.types.afs.reader;
const services = @import("hikari").efi.types.services;
const types = @import("tests").efi.types.firmware.storage;

var state: types.State = undefined;
var active: bool = false;

pub fn run(real: *services.boot.BootServices) !void {
    state = .{ .Real = real };
    active = true;
    defer if (!cleanup()) output.fail(labels.CLEANUP_FAILED);
    var wrapped = real.*;
    wrapped.AllocatePool = allocatePool;
    wrapped.FreePool = freePool;
    require(scratchDiscovery(&wrapped, false), labels.DISCOVERY_RELEASE);
    require(scratchDiscovery(&wrapped, true), labels.DISCOVERY_REFUSAL);
    var discovery: partition.Discovery = .{ .Parser = .{ .BootServices = real } };
    defer if (!locator.deinitialize(&discovery)) output.fail(labels.CLEANUP_FAILED);
    const found = (try locator.findAfsPartition(&discovery)) orelse return error.NotFound;
    require(discovery.Handles.isEmpty() and discovery.Parser.Scratch.Pool.isEmpty() and state.LivePools == 0, labels.PARTITION);
    state.Reader = .{ .BootServices = &wrapped };
    const reader = &state.Reader.?;
    try reader.initialize(found.Media, found.StartLBA, found.EndLBA);
    require(reader.Index.Depth >= inputs.MINIMUM_DEPTH and reader.Index.TotalNodes > inputs.FORMER_INDEX_NODES and
        reader.VolumeHeader.IndexDepth == reader.Index.Depth and reader.VolumeHeader.IndexTotalNodes == reader.Index.TotalNodes, labels.SHAPE);
    const nested = try nestedNode(reader);
    require(nested != null, labels.NESTED);
    require(try allPayloads(reader), labels.PAYLOADS);
    require(try missingQueries(reader), labels.MISSING);
    require(try exactFences(reader, nested.?), labels.FENCES);
    const first = (try reader.Index.readNode(reader.Index.FirstLeaf)).*;
    const last = (try reader.Index.readNode(reader.Index.LastLeaf)).*;
    require(first.isLeaf() and last.isLeaf() and first.Height == 1 and last.Height == 1 and
        first.BackwardLink == 0 and last.ForwardLink == 0, labels.LEAVES);
    const source_released = try readOwnership(reader, &wrapped);
    const scratch_released = scratchReader(&wrapped);
    const released = cleanup();
    require(released, labels.RELEASED);
    require(source_released, labels.SOURCE_RELEASE);
    require(scratch_released, labels.SCRATCH_RELEASE);
}

fn scratchDiscovery(wrapped: *services.boot.BootServices, persistent: bool) bool {
    const locate = wrapped.LocateHandleBuffer;
    wrapped.LocateHandleBuffer = locateHandles;
    defer wrapped.LocateHandleBuffer = locate;
    state.SourceFreeCalls = 0;
    state.RefuseSourceReleases = if (persistent) 3 else 1;
    defer state.RefuseSourceReleases = 1;
    var claims: claimtypes.Claims = .{ .Paging = .{ .BootServices = wrapped }, .Discovery = .{ .Parser = .{ .BootServices = wrapped } } };
    const refused = rejectsDiscovery(&claims.Discovery.?);
    const allocation = state.Source;
    const retained = allocation != null and claims.Discovery.?.Handles.Allocation == allocation and
        claims.Discovery.?.Parser.Scratch.Pool.isEmpty() and state.SourceFreeCalls == 1 and state.LivePools == 1;
    const allocations = state.Allocations;
    const reentry_refused = rejectsDiscovery(&claims.Discovery.?);
    const cleaned = abort.finish(&claims);
    const result = if (persistent)
        !cleaned and state.SourceFreeCalls == 3 and state.Source == allocation and claims.Discovery != null and
            claims.Discovery.?.Handles.Allocation == allocation and state.LivePools == 1
    else
        cleaned and state.SourceFreeCalls == 2 and state.Source == null and claims.Discovery == null and state.LivePools == 0;
    state.RefuseSourceReleases = 0;
    const recovered = abort.finish(&claims) and abort.finish(&claims);
    const exact = state.SourceFreeCalls == (if (persistent) @as(usize, 4) else 2) and state.Allocations == allocations;
    state.SourceFreeCalls = 0;
    return refused and retained and reentry_refused and result and recovered and exact and state.LivePools == 0;
}

fn rejectsDiscovery(discovery: *partition.Discovery) bool {
    return if (locator.findAfsPartition(discovery)) |_| false else |failure| failure == error.ReleaseFailed;
}

fn scratchReader(wrapped: *services.boot.BootServices) bool {
    const allocation = state.Reader.?.CellAllocation.Pool.Allocation orelse return false;
    var claims: claimtypes.Claims = .{ .Paging = .{ .BootServices = wrapped }, .Reader = state.Reader };
    state.Reader = null;
    state.Source = allocation;
    state.SourceFreeCalls = 0;
    const allocations = state.Allocations;
    const refused = !abort.releaseReader(&claims);
    const retained = state.Source == allocation and claims.Reader != null and claims.Reader.?.CellAllocation.Pool.Allocation == allocation and
        claims.Reader.?.NodeAllocation.isEmpty() and state.SourceFreeCalls == 1 and state.LivePools == 1;
    const closed = if (claims.Reader) |*reader|
        if (reader.Index.readNode(1)) |_| false else |failure| failure == error.InvalidNode
    else
        false;
    const released = abort.finish(&claims) and abort.finish(&claims);
    state.Reader = claims.Reader;
    return refused and retained and closed and released and claims.Reader == null and state.Source == null and state.SourceFreeCalls == 2 and
        state.Allocations == allocations and state.LivePools == 0;
}

fn locateHandles(search: efi.types.memory.LocateSearchType, protocol: ?*align(8) const base.GUID, key: ?*anyopaque, count: *usize, handles: *[*]base.Handle) callconv(convention.CALLING_CONVENTION) base.Status {
    const result = state.Real.LocateHandleBuffer(search, protocol, key, count, handles);
    if (result == codes.SUCCESS) {
        state.Source = @ptrCast(handles.*);
        state.LivePools += 1;
        state.Allocations += 1;
    }
    return result;
}

fn readOwnership(reader: *readers.Reader, wrapped: *services.boot.BootServices) !bool {
    var identity: [inputs.IDENTITY_BYTES]u8 = undefined;
    createIdentity(0, &identity);
    var location: [labels.LOCATION_PREFIX.len + inputs.IDENTITY_BYTES]u8 = undefined;
    const path = try std.fmt.bufPrint(&location, labels.LOCATION_FORMAT, .{&identity});
    var unit = try reader.openLocation(path);
    unit.DataChannel.PhysicalSize = 0;
    var claims: claimtypes.Claims = .{ .Paging = .{ .BootServices = wrapped } };
    const initial_pools = state.LivePools;
    state.CaptureSource = true;
    const rejected = if (reader.readUnitToAllocated(&unit, inputs.PAYLOAD_BYTES, &claims.Source)) |_| false else |failure| failure == error.InvalidSpan;
    const retained = claims.Source.Allocation != null and claims.Source.Allocation == state.Source and state.LivePools == initial_pools + 1 and
        state.SourceFreeCalls == 0;
    const released = abort.finish(&claims);
    return rejected and retained and released and claims.Source.isEmpty() and state.Source == null and
        state.SourceFreeCalls == 2 and state.LivePools == initial_pools;
}

pub fn cleanup() bool {
    if (!active) return true;
    const reader_released = if (state.Reader) |*reader| reader.deinitialize() else true;
    if (reader_released) state.Reader = null;
    if (state.Source) |source| _ = freePool(source);
    const valid = reader_released and !state.Broken and state.LivePools == 0 and state.Allocations == state.Releases;
    active = false;
    return valid;
}

fn require(condition: bool, comptime label: []const u8) void {
    if (!condition) _ = cleanup();
    output.require(condition, label);
}

fn nestedNode(reader: *readers.Reader) !?u32 {
    var parent: u32 = afs.constants.nodes.ORIGIN_STACK;
    for ([_][]const u8{ labels.CHECKS_IDENTITY, labels.STORAGE_IDENTITY, labels.NESTED_IDENTITY }) |name| {
        var identity: [inputs.IDENTITY_BYTES]u16 = undefined;
        for (name, 0..) |byte, index| identity[index] = byte;
        const stack = (try reader.Index.searchIndexForStack(parent, identity[0..name.len])) orelse return null;
        parent = stack.NodeId;
    }
    return parent;
}

fn allPayloads(reader: *readers.Reader) !bool {
    for (0..inputs.UNIT_COUNT) |index| {
        var identity: [inputs.IDENTITY_BYTES]u8 = undefined;
        createIdentity(index * inputs.IDENTITY_STRIDE, &identity);
        if (!try readNamed(reader, &identity, index)) return false;
    }
    return true;
}

fn missingQueries(reader: *readers.Reader) !bool {
    var location: [labels.LOCATION_PREFIX.len + inputs.IDENTITY_BYTES]u8 = undefined;
    for (0..inputs.UNIT_COUNT) |index| {
        var identity: [inputs.IDENTITY_BYTES]u8 = undefined;
        createIdentity(index * inputs.IDENTITY_STRIDE, &identity);
        if (!try isMissing(reader, &identity)) return false;
        createIdentity(index * inputs.IDENTITY_STRIDE + 1, &identity);
        const path = try std.fmt.bufPrint(&location, labels.LOCATION_FORMAT, .{&identity});
        if (!try isMissing(reader, path)) return false;
    }
    return isMissing(reader, labels.NESTED_PATH);
}

fn isMissing(reader: *readers.Reader, path: []const u8) !bool {
    _ = reader.openLocation(path) catch |failure| {
        if (failure == error.NotFound) return true;
        return failure;
    };
    return false;
}

fn readNamed(reader: *readers.Reader, identity: []const u8, ordinal: usize) !bool {
    var location: [labels.LOCATION_PREFIX.len + inputs.IDENTITY_BYTES]u8 = undefined;
    const path = try std.fmt.bufPrint(&location, labels.LOCATION_FORMAT, .{identity});
    const unit = try reader.openLocation(path);
    if (unit.DataChannel.LogicalSize != inputs.PAYLOAD_BYTES) return false;
    var actual: [inputs.PAYLOAD_BYTES]u8 = undefined;
    const read = try reader.readUnit(&unit, &actual, actual.len);
    var expected: [inputs.PAYLOAD_BYTES]u8 = undefined;
    std.mem.writeInt(u32, expected[0..inputs.PAYLOAD_INDEX_BYTES], @intCast(ordinal), .little);
    @memcpy(expected[inputs.PAYLOAD_INDEX_BYTES..], &inputs.PAYLOAD_SUFFIX);
    return read == expected.len and std.mem.eql(u8, &expected, &actual);
}

fn exactFences(reader: *readers.Reader, parent: u32) !bool {
    var count: usize = 0;
    var saw_root = false;
    var saw_lower = false;
    var number: u32 = 1;
    while (number < reader.Index.TotalNodes) : (number += 1) {
        const descriptor = (try reader.Index.readNode(number)).*;
        if (!descriptor.isIndex()) continue;
        var record_index: u16 = 0;
        while (record_index < descriptor.RecordCount) : (record_index += 1) {
            const current = try reader.Index.readNode(number);
            const pointer = afs.btree.node.getRecordPointer(@ptrCast(current), reader.Index.NodeSize, record_index);
            const key: *align(1) const afs.types.btree.records.IndexKey = @ptrCast(pointer);
            if (key.ParentNodeId != parent) continue;
            if (key.getIdentityLength() != inputs.IDENTITY_BYTES) return false;
            var identity: [inputs.IDENTITY_BYTES]u8 = undefined;
            for (&identity, 0..) |*byte, index| {
                if (key.Identity[index] > std.math.maxInt(u8)) return false;
                byte.* = @intCast(key.Identity[index]);
            }
            const ordinal = decodeOrdinal(&identity) orelse return false;
            if (!try readNamed(reader, &identity, ordinal)) return false;
            count += 1;
            saw_root = saw_root or descriptor.Height == reader.Index.Depth;
            saw_lower = saw_lower or descriptor.Height < reader.Index.Depth;
        }
    }
    return count >= inputs.MINIMUM_FENCES and saw_root and saw_lower;
}

fn createIdentity(value: usize, identity: *[inputs.IDENTITY_BYTES]u8) void {
    @memset(identity, inputs.NAME_BYTE);
    const suffix = identity.len - inputs.SUFFIX_BYTES;
    identity[suffix] = inputs.DIGIT_ZERO + @as(u8, @intCast(value / inputs.DECIMAL_HUNDREDS));
    identity[suffix + 1] = inputs.DIGIT_ZERO + @as(u8, @intCast(value / inputs.DECIMAL_TENS % inputs.DECIMAL_TENS));
    identity[suffix + 2] = inputs.DIGIT_ZERO + @as(u8, @intCast(value % inputs.DECIMAL_TENS));
}

fn decodeOrdinal(identity: []const u8) ?usize {
    const suffix = identity.len - inputs.SUFFIX_BYTES;
    if (!std.mem.allEqual(u8, identity[0..suffix], inputs.NAME_BYTE)) return null;
    var value: usize = 0;
    for (identity[suffix..]) |byte| {
        if (byte < inputs.DIGIT_ZERO or byte >= inputs.DIGIT_ZERO + inputs.DECIMAL_TENS) return null;
        value = value * inputs.DECIMAL_TENS + byte - inputs.DIGIT_ZERO;
    }
    if (value % inputs.IDENTITY_STRIDE != 0 or value / inputs.IDENTITY_STRIDE >= inputs.UNIT_COUNT) return null;
    return value / inputs.IDENTITY_STRIDE;
}

fn allocatePool(pool_type: efi.types.memory.MemoryType, size: usize, allocation: *[*]align(8) u8) callconv(convention.CALLING_CONVENTION) base.Status {
    if (!active) return codes.INVALID_PARAMETER;
    const result = state.Real.AllocatePool(pool_type, size, allocation);
    if (!efi.status.isError(result)) {
        state.Allocations += 1;
        state.LivePools += 1;
        if (state.CaptureSource) {
            state.Source = allocation.*;
            state.CaptureSource = false;
        }
    }
    return result;
}

fn freePool(allocation: [*]align(8) u8) callconv(convention.CALLING_CONVENTION) base.Status {
    if (!active) return codes.INVALID_PARAMETER;
    const source = state.Source != null and state.Source.? == allocation;
    if (source) {
        state.SourceFreeCalls += 1;
        if (state.SourceFreeCalls <= state.RefuseSourceReleases) return codes.DEVICE_ERROR;
    }
    const result = state.Real.FreePool(allocation);
    if (efi.status.isError(result)) {
        state.Broken = true;
    } else {
        if (source) state.Source = null;
        state.Releases += 1;
        if (state.LivePools == 0) {
            state.Broken = true;
        } else {
            state.LivePools -= 1;
        }
    }
    return result;
}
