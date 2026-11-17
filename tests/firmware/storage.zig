//! Real Hikari Acquisition Of Writer Produced Multi Level AFS

const std = @import("std");

const afs = @import("shared").afs;
const base = @import("hikari").efi.types.base;
const codes = @import("hikari").efi.constants.status;
const convention = @import("hikari").efi.constants.convention;
const efi = @import("hikari").efi;
const inputs = @import("tests").firmware.constants.storage;
const labels = @import("tests").firmware.strings.storage;
const locator = @import("hikari").sequence.partition;
const output = @import("tests").firmware.run;
const readers = @import("hikari").fs.types.afs.reader;
const services = @import("hikari").efi.types.services;
const types = @import("tests").firmware.types.storage;

var state: types.State = undefined;
var active: bool = false;

pub fn run(real: *services.boot.BootServices) !void {
    const partition = locator.findAfsPartition(real);
    require(partition != null, labels.PARTITION);
    state = .{ .Real = real };
    active = true;
    defer if (!cleanup()) output.fail(labels.CLEANUP_FAILED);
    var wrapped = real.*;
    wrapped.AllocatePool = allocatePool;
    wrapped.FreePool = freePool;
    const found = partition.?;
    state.Reader = try readers.Reader.initialize(found.BlockIO, &wrapped, found.StartLBA, found.EndLBA);
    const reader = if (state.Reader) |*source| source else unreachable;
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
    const released = cleanup();
    require(released, labels.RELEASED);
}

pub fn cleanup() bool {
    if (!active) return true;
    if (state.Reader) |*reader| reader.deinitialize();
    state.Reader = null;
    const valid = !state.Broken and state.LivePools == 0 and state.Allocations == state.Releases;
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
            _ = try reader.Index.readNode(number);
            const pointer = reader.Index.getRecordPointer(record_index);
            const key: *align(1) const afs.types.btree.IndexKey = @ptrCast(pointer);
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
    }
    return result;
}

fn freePool(allocation: [*]align(8) u8) callconv(convention.CALLING_CONVENTION) base.Status {
    if (!active) return codes.INVALID_PARAMETER;
    const result = state.Real.FreePool(allocation);
    if (efi.status.isError(result)) {
        state.Broken = true;
    } else {
        state.Releases += 1;
        if (state.LivePools == 0) {
            state.Broken = true;
        } else {
            state.LivePools -= 1;
        }
    }
    return result;
}
