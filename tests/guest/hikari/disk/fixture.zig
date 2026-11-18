//! EFI Disk Acquisition Fixtures And External Callbacks

const std = @import("std");

const afs = @import("shared").afs;
const base = @import("hikari").efi.types.base;
const block = @import("hikari").efi.types.block;
const boot = @import("hikari").efi.types.services.boot;
const constants = @import("tests").constants.acquisition;
const convention = @import("hikari").efi.constants.convention;
const crc = @import("utils").crc.checksum;
const guids = @import("hikari").efi.constants.guids;
const labels = @import("tests").strings.acquisition;
const memory = @import("hikari").efi.types.memory;
const protocols = @import("hikari").efi.types.protocols.block;
const status = @import("hikari").efi.constants.status;
const types = @import("tests").types.acquisition;

pub var device: types.Device = .{};
pub var media: block.BlockIoMedia = undefined;
pub var protocol: protocols.BlockIoProtocol = undefined;
pub var services: boot.BootServices = undefined;

var replacement: block.BlockIoMedia = undefined;
var replacement_lba: ?u64 = null;

pub fn reset() void {
    if (live() != 0) @panic(labels.FIXTURE_LIFETIME);
    @memset(&device.Disk, 0);
    @memset(&device.Requested, 0);
    for (&device.Slots) |*slot| {
        @memset(&slot.Bytes, constants.POOL_GUARD);
        slot.InUse = false;
        slot.Size = 0;
    }
    device.AllocateCalls = 0;
    device.FreeCalls = 0;
    device.ReadCalls = 0;
    device.FailAllocation = null;
    device.FailLBA = null;
    device.Broken = false;
    replacement_lba = null;
    media = .{
        .MediaId = constants.MEDIA_ID,
        .RemovableMedia = false,
        .MediaPresent = true,
        .LogicalPartition = false,
        .ReadOnly = true,
        .WriteCaching = false,
        .BlockSize = constants.BLOCK_BYTES,
        .IOAlign = constants.IO_ALIGNMENT,
        .LastBlock = constants.DISK_BLOCKS - 1,
        .LowestAlignedLBA = 0,
        .LogicalBlocksPerPhysicalBlock = 1,
        .OptimalTransferLengthGranularity = 1,
    };
    protocol = undefined;
    protocol.Revision = 0x00010000;
    protocol.Media = &media;
    protocol.ReadBlocks = readBlocks;
    services = undefined;
    services.AllocatePool = allocatePool;
    services.FreePool = freePool;
    services.HandleProtocol = handleProtocol;
    services.LocateHandleBuffer = locateHandleBuffer;
}

pub fn changeMediaAfterRead(lba: u64, next: block.BlockIoMedia) void {
    replacement = next;
    replacement_lba = lba;
}

pub fn live() usize {
    var count: usize = 0;
    for (&device.Slots) |*slot| {
        if (slot.InUse) count += 1;
    }
    return count;
}

pub fn clean() bool {
    return !device.Broken and live() == 0;
}

pub fn headerBytes() []u8 {
    return device.Disk[media.BlockSize..][0..media.BlockSize];
}

pub fn tableBytes() []u8 {
    return device.Disk[constants.TABLE_LBA * constants.BLOCK_BYTES ..][0..constants.TABLE_READ_BYTES];
}

pub fn writeU32(bytes: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, bytes[offset..][0..4], value, .little);
}

pub fn writeU64(bytes: []u8, offset: usize, value: u64) void {
    std.mem.writeInt(u64, bytes[offset..][0..8], value, .little);
}

pub fn sealHeader() void {
    const header = headerBytes();
    writeU32(header, 16, 0);
    writeU32(header, 16, crc.calculate(header[0..constants.HEADER_BYTES]));
}

pub fn encodeGPT() void {
    const table = tableBytes();
    @memset(table, constants.TABLE_PADDING);
    @memset(table[0..constants.TABLE_BYTES], 0);
    partition(table, 0, constants.TYPE_A, 8, 15);
    partition(table, 1, constants.TYPE_A, 10, 9);
    partition(table, 2, constants.TYPE_B, constants.PARTITION_FIRST_LBA, constants.PARTITION_LAST_LBA);
    partition(table, 3, constants.TYPE_A, constants.DISK_BLOCKS - 1, constants.DISK_BLOCKS - 1);
    const header = headerBytes();
    @memset(header, 0);
    @memcpy(header[0..8], labels.GPT_SIGNATURE);
    writeU32(header, 8, 0x00010000);
    writeU32(header, 12, constants.HEADER_BYTES);
    writeU64(header, 24, constants.HEADER_LBA);
    writeU64(header, 32, constants.DISK_BLOCKS - 1);
    writeU64(header, 40, constants.FIRST_USABLE_LBA);
    writeU64(header, 48, constants.LAST_USABLE_LBA);
    guid(header[56..72], constants.DISK_GUID);
    writeU64(header, 72, constants.TABLE_LBA);
    writeU32(header, 80, constants.ENTRY_COUNT);
    writeU32(header, 84, constants.ENTRY_BYTES);
    writeU32(header, 88, crc.calculate(table[0..constants.TABLE_BYTES]));
    sealHeader();
}

pub fn encodeExpandedGPT(block_size: u32, count: u32) void {
    media.BlockSize = block_size;
    media.LastBlock = constants.DISK_BYTES / block_size - 1;
    const table_size = @as(usize, count) * constants.ENTRY_BYTES;
    const table_blocks = (table_size - 1) / block_size + 1;
    const table = device.Disk[constants.TABLE_LBA * block_size ..][0 .. table_blocks * block_size];
    @memset(table, 0);
    const first = constants.TABLE_LBA + table_blocks;
    partition(table, count - 1, constants.TYPE_B, first, media.LastBlock - 1);
    const header = headerBytes();
    @memset(header, 0);
    @memcpy(header[0..8], labels.GPT_SIGNATURE);
    writeU32(header, 8, 0x00010000);
    writeU32(header, 12, constants.HEADER_BYTES);
    writeU64(header, 24, constants.HEADER_LBA);
    writeU64(header, 32, media.LastBlock);
    writeU64(header, 40, first);
    writeU64(header, 48, media.LastBlock - 1);
    guid(header[56..72], constants.DISK_GUID);
    writeU64(header, 72, constants.TABLE_LBA);
    writeU32(header, 80, count);
    writeU32(header, 84, constants.ENTRY_BYTES);
    writeU32(header, 88, crc.calculate(table[0..table_size]));
    sealHeader();
}

fn guid(bytes: []u8, value: base.GUID) void {
    writeU32(bytes, 0, value.TimeLow);
    std.mem.writeInt(u16, bytes[4..6], value.TimeMid, .little);
    std.mem.writeInt(u16, bytes[6..8], value.TimeHighAndVersion, .little);
    @memcpy(bytes[8..16], &value.ClockSequenceAndNode);
}

fn partition(table: []u8, index: usize, type_guid: base.GUID, first: u64, last: u64) void {
    const entry = table[index * constants.ENTRY_BYTES ..][0..constants.ENTRY_BYTES];
    guid(entry[0..16], type_guid);
    var unique = constants.DISK_GUID;
    unique.TimeLow = @intCast(0xF0000000 + index);
    guid(entry[16..32], unique);
    writeU64(entry, 32, first);
    writeU64(entry, 40, last);
}

pub fn encodeAFS() void {
    const start = constants.PARTITION_FIRST_LBA * constants.BLOCK_BYTES;
    const volume: afs.types.volume.VolumeHeader = .{
        .CellSize = constants.BLOCK_BYTES,
        .TotalCells = constants.VOLUME_CELLS,
        .FreeCells = constants.VOLUME_CELLS - 4,
        .IndexNodeSize = constants.BLOCK_BYTES,
        .IndexTotalNodes = 2,
        .IndexFreeNodes = 1,
        .IndexRootNode = 0,
        .IndexFirstLeaf = 0,
        .IndexLastLeaf = 0,
        .IndexDepth = 0,
        .IndexSpan = .{ .StartCell = 1, .CellCount = 2 },
    };
    @memcpy(device.Disk[start..][0..@sizeOf(afs.types.volume.VolumeHeader)], std.mem.asBytes(&volume));
    const descriptor: afs.types.btree.NodeDescriptor = .{
        .NodeType = afs.constants.btree.NODE_TYPE_HEADER,
        .RecordCount = 1,
    };
    const header: afs.types.btree.HeaderRecord = .{
        .Depth = 0,
        .RootNode = 0,
        .FirstLeafNode = 0,
        .LastLeafNode = 0,
        .NodeSize = constants.BLOCK_BYTES,
        .TotalNodes = 2,
        .FreeNodes = 1,
    };
    const node = start + constants.BLOCK_BYTES;
    @memcpy(device.Disk[node..][0..@sizeOf(afs.types.btree.NodeDescriptor)], std.mem.asBytes(&descriptor));
    @memcpy(device.Disk[node + @sizeOf(afs.types.btree.NodeDescriptor) ..][0..@sizeOf(afs.types.btree.HeaderRecord)], std.mem.asBytes(&header));
    const leaf: afs.types.btree.NodeDescriptor = .{ .NodeType = afs.constants.btree.NODE_TYPE_LEAF, .Height = 1 };
    @memcpy(device.Disk[node + constants.BLOCK_BYTES ..][0..@sizeOf(afs.types.btree.NodeDescriptor)], std.mem.asBytes(&leaf));
    const payload = start + constants.PAYLOAD_CELL * constants.BLOCK_BYTES;
    @memcpy(device.Disk[payload..][0..constants.UNIT_PAYLOAD.len], &constants.UNIT_PAYLOAD);
}

pub fn unit() afs.types.catalog.UnitRecord {
    var result: afs.types.catalog.UnitRecord = .{};
    result.DataChannel = .{
        .LogicalSize = constants.UNIT_PAYLOAD.len,
        .PhysicalSize = constants.BLOCK_BYTES,
        .ClumpSize = constants.BLOCK_BYTES,
        .TotalCells = 1,
    };
    result.DataChannel.Spans[0] = .{ .StartCell = constants.PAYLOAD_CELL, .CellCount = 1 };
    return result;
}

fn allocatePool(pool_type: memory.MemoryType, size: usize, allocation: *[*]align(8) u8) callconv(convention.CALLING_CONVENTION) base.Status {
    device.AllocateCalls += 1;
    if (device.AllocateCalls > device.Requested.len or pool_type != .LoaderData) {
        device.Broken = true;
        return status.INVALID_PARAMETER;
    }
    device.Requested[device.AllocateCalls - 1] = size;
    if (device.FailAllocation == device.AllocateCalls or size == 0 or size > constants.POOL_BYTES - 2 * constants.POOL_OFFSET) return status.OUT_OF_RESOURCES;
    for (&device.Slots) |*slot| {
        if (slot.InUse) continue;
        @memset(&slot.Bytes, constants.POOL_GUARD);
        slot.Size = size;
        slot.InUse = true;
        allocation.* = @ptrCast(@alignCast(&slot.Bytes[constants.POOL_OFFSET]));
        return status.SUCCESS;
    }
    return status.OUT_OF_RESOURCES;
}

fn freePool(allocation: [*]align(8) u8) callconv(convention.CALLING_CONVENTION) base.Status {
    device.FreeCalls += 1;
    for (&device.Slots) |*slot| {
        if (@intFromPtr(allocation) != @intFromPtr(&slot.Bytes[constants.POOL_OFFSET])) continue;
        if (!slot.InUse or !std.mem.allEqual(u8, slot.Bytes[0..constants.POOL_OFFSET], constants.POOL_GUARD) or
            !std.mem.allEqual(u8, slot.Bytes[constants.POOL_OFFSET + slot.Size ..], constants.POOL_GUARD))
        {
            device.Broken = true;
            return status.INVALID_PARAMETER;
        }
        slot.InUse = false;
        return status.SUCCESS;
    }
    device.Broken = true;
    return status.INVALID_PARAMETER;
}

fn locateHandleBuffer(search_type: memory.LocateSearchType, protocol_guid: ?*align(8) const base.GUID, search_key: ?*anyopaque, handle_count: *usize, handles: *[*]base.Handle) callconv(convention.CALLING_CONVENTION) base.Status {
    const requested = protocol_guid orelse return status.INVALID_PARAMETER;
    if (search_type != .ByProtocol or !requested.equals(guids.BLOCK_IO_PROTOCOL) or search_key != null) return status.INVALID_PARAMETER;
    var buffer: [*]align(8) u8 = undefined;
    const allocation = allocatePool(.LoaderData, @sizeOf(base.Handle), &buffer);
    if (allocation != status.SUCCESS) return allocation;
    handles.* = @ptrCast(buffer);
    handles.*[0] = @ptrCast(&protocol);
    handle_count.* = 1;
    return status.SUCCESS;
}

fn handleProtocol(handle: base.Handle, protocol_guid: *align(8) const base.GUID, interface: *?*anyopaque) callconv(convention.CALLING_CONVENTION) base.Status {
    if (handle != @as(base.Handle, @ptrCast(&protocol)) or !protocol_guid.equals(guids.BLOCK_IO_PROTOCOL)) return status.INVALID_PARAMETER;
    interface.* = &protocol;
    return status.SUCCESS;
}

fn readBlocks(self: *protocols.BlockIoProtocol, media_id: u32, lba: base.LBA, buffer_size: usize, buffer: [*]u8) callconv(convention.CALLING_CONVENTION) base.Status {
    if (device.ReadCalls >= device.Reads.len) {
        device.Broken = true;
        return status.DEVICE_ERROR;
    }
    device.Reads[device.ReadCalls] = .{ .LBA = lba, .Bytes = buffer_size, .Address = @intFromPtr(buffer) };
    device.ReadCalls += 1;
    if (self != &protocol) return status.INVALID_PARAMETER;
    if (!media.MediaPresent) return status.NO_MEDIA;
    if (media_id != media.MediaId) return status.MEDIA_CHANGED;
    if (lba > media.LastBlock or media.BlockSize == 0 or buffer_size == 0 or buffer_size % media.BlockSize != 0 or
        @intFromPtr(buffer) % @max(media.IOAlign, 1) != 0 or lba >= device.Disk.len / media.BlockSize)
    {
        device.Broken = true;
        return status.INVALID_PARAMETER;
    }
    const offset = @as(usize, @intCast(lba)) * media.BlockSize;
    if (buffer_size > device.Disk.len - offset) {
        device.Broken = true;
        return status.INVALID_PARAMETER;
    }
    if (device.FailLBA == lba) return status.DEVICE_ERROR;
    @memcpy(buffer[0..buffer_size], device.Disk[offset..][0..buffer_size]);
    if (replacement_lba == lba) {
        media = replacement;
        replacement_lba = null;
    }
    return status.SUCCESS;
}
