//! AFS Writer for mkafsdisk

const std = @import("std");

const afs = @import("shared").afs;

const constants = @import("../constants/constants.zig");
const strings = @import("../strings/strings.zig");

const layout = constants.afs;
const messages = strings.messages;

const BTreeHeaderRecord = afs.types.btree.HeaderRecord;
const BTreeNodeDescriptor = afs.types.btree.NodeDescriptor;
const IndexKey = afs.types.btree.IndexKey;
const JournalHeader = afs.types.journal.JournalHeader;
const JournalInfoCell = afs.types.journal.JournalInfoCell;
const SpanDescriptor = afs.types.volume.SpanDescriptor;
const StackRecord = afs.types.catalog.StackRecord;
const UnitRecord = afs.types.catalog.UnitRecord;
const VolumeHeader = afs.types.volume.VolumeHeader;

pub const Writer = struct {
    File: std.fs.File,
    PartitionStartByte: u64,
    PartitionSizeBytes: u64,
    CellSize: u32,
    TotalCells: u32,
    Allocator: std.mem.Allocator,

    NextCell: u32,
    NextNodeId: u32,
    UnitCount: u32,
    StackCount: u32,

    AllocationMapStartCell: u32,
    AllocationMapCells: u32,
    IndexStartCell: u32,
    IndexCells: u32,
    JournalStartCell: u32,
    JournalCells: u32,
    DataStartCell: u32,

    IndexRecordOffset: usize,

    const Self = @This();

    pub fn initialize(
        file: std.fs.File,
        partition_start_byte: u64,
        partition_size_bytes: u64,
        allocator: std.mem.Allocator,
    ) Self {
        const cell_size = afs.constants.sizes.DEFAULT_CELL_SIZE;
        const total_cells: u32 = @intCast(partition_size_bytes / cell_size);

        const index_start: u32 = layout.ALLOCATION_MAP_START_CELL + layout.ALLOCATION_MAP_CELLS;
        const data_start: u32 = index_start + layout.INDEX_CELLS;

        return Self{
            .File = file,
            .PartitionStartByte = partition_start_byte,
            .PartitionSizeBytes = partition_size_bytes,
            .CellSize = cell_size,
            .TotalCells = total_cells,
            .Allocator = allocator,
            .NextCell = data_start,
            .NextNodeId = afs.constants.nodes.FIRST_USER,
            .UnitCount = 0,
            .StackCount = 0,
            .AllocationMapStartCell = layout.ALLOCATION_MAP_START_CELL,
            .AllocationMapCells = layout.ALLOCATION_MAP_CELLS,
            .IndexStartCell = index_start,
            .IndexCells = layout.INDEX_CELLS,
            .JournalStartCell = layout.JOURNAL_START_CELL,
            .JournalCells = layout.JOURNAL_CELLS,
            .DataStartCell = data_start,
            .IndexRecordOffset = @sizeOf(BTreeNodeDescriptor),
        };
    }

    pub fn createFilesystem(self: *Self, source_location: []const u8) !void {
        std.debug.print(messages.AFS_CREATING, .{});
        std.debug.print(messages.AFS_TOTAL_CELLS, .{self.TotalCells});
        std.debug.print(messages.AFS_CELL_SIZE, .{self.CellSize});

        try self.writeJournalInfo();
        try self.writeJournalHeader();

        const index_buffer = try self.Allocator.alloc(u8, self.IndexCells * self.CellSize);
        defer self.Allocator.free(index_buffer);
        @memset(index_buffer, 0);

        try self.writeIndexHeader(index_buffer);

        const origin_node_id = afs.constants.nodes.ORIGIN_STACK;
        try self.addStackToIndex(
            index_buffer,
            origin_node_id,
            afs.constants.nodes.ORIGIN,
            "",
        );
        self.StackCount += 1;

        try self.copyStackRecursive(source_location, origin_node_id, index_buffer);

        try self.writeIndex(index_buffer);
        try self.writeAllocationMap();
        try self.writeVolumeHeader();
        try self.writeAlternateVolumeHeader();

        std.debug.print(messages.AFS_COUNTS, .{ self.UnitCount, self.StackCount });
        std.debug.print(messages.AFS_FREE_CELLS, .{self.TotalCells - self.NextCell});
    }

    fn copyStackRecursive(
        self: *Self,
        source_location: []const u8,
        parent_node_id: u32,
        index_buffer: []u8,
    ) !void {
        var host_stack = std.fs.cwd().openDir(source_location, .{ .iterate = true }) catch |err| {
            std.debug.print(messages.AFS_OPEN_WARNING, .{ source_location, err });
            return;
        };
        defer host_stack.close();

        var iterator = host_stack.iterate();
        while (try iterator.next()) |entry| {
            if (entry.name[0] == '.') continue;

            const node_id = self.NextNodeId;
            self.NextNodeId += 1;

            if (entry.kind == .directory) {
                try self.addStackToIndex(index_buffer, node_id, parent_node_id, entry.name);
                self.StackCount += 1;

                const sub_location = try std.fs.path.join(self.Allocator, &.{ source_location, entry.name });
                defer self.Allocator.free(sub_location);

                std.debug.print(messages.AFS_ADDED_STACK, .{entry.name});
                try self.copyStackRecursive(sub_location, node_id, index_buffer);
            } else {
                const unit_location = try std.fs.path.join(self.Allocator, &.{ source_location, entry.name });
                defer self.Allocator.free(unit_location);

                try self.addUnitToIndex(index_buffer, node_id, parent_node_id, entry.name, unit_location);
                self.UnitCount += 1;

                std.debug.print(messages.AFS_ADDED_UNIT, .{entry.name});
            }
        }
    }

    fn addStackToIndex(
        self: *Self,
        index_buffer: []u8,
        node_id: u32,
        parent_node_id: u32,
        identity: []const u8,
    ) !void {
        const timestamp = @as(u64, @intCast(std.time.timestamp()));

        var record = afs.write.stack.createStackRecord(node_id, timestamp, 0o755);

        try self.writeIndexRecord(index_buffer, parent_node_id, identity, std.mem.asBytes(&record));
    }

    fn addUnitToIndex(
        self: *Self,
        index_buffer: []u8,
        node_id: u32,
        parent_node_id: u32,
        identity: []const u8,
        unit_path: []const u8,
    ) !void {
        const source_file = try std.fs.cwd().openFile(unit_path, .{});
        defer source_file.close();

        const file_size = try source_file.getEndPos();
        const cells_needed = afs.write.unit.cellsNeeded(file_size, self.CellSize);

        const start_cell = self.NextCell;
        self.NextCell += cells_needed;

        if (cells_needed > 0) {
            var remaining = file_size;
            var current_cell = start_cell;
            const buffer = try self.Allocator.alloc(u8, self.CellSize);
            defer self.Allocator.free(buffer);

            while (remaining > 0) {
                @memset(buffer, 0);
                const to_read = @min(remaining, self.CellSize);
                const bytes_read = try source_file.read(buffer[0..to_read]);
                if (bytes_read == 0) break;

                try self.writeCell(current_cell, buffer);
                remaining -= bytes_read;
                current_cell += 1;
            }
        }

        const timestamp = @as(u64, @intCast(std.time.timestamp()));

        const data_channel = afs.write.unit.createChannelInfo(file_size, start_cell, cells_needed, self.CellSize);
        var record = afs.write.stack.createUnitRecord(node_id, timestamp, 0o644, data_channel);

        try self.writeIndexRecord(index_buffer, parent_node_id, identity, std.mem.asBytes(&record));
    }

    fn writeIndexHeader(self: *Self, index_buffer: []u8) !void {
        var node_descriptor = BTreeNodeDescriptor{
            .ForwardLink = 0,
            .BackwardLink = 0,
            .NodeType = afs.constants.btree.NODE_TYPE_HEADER,
            .Height = 0,
            .RecordCount = layout.INDEX_HEADER_RECORD_COUNT,
            .Reserved = 0,
        };

        const header_record = BTreeHeaderRecord{
            .Depth = 1,
            .RootNode = 1,
            .LeafRecordCount = 0,
            .FirstLeafNode = 1,
            .LastLeafNode = 1,
            .NodeSize = @intCast(self.CellSize),
            .MaxKeyLength = layout.MAX_KEY_LENGTH,
            .TotalNodes = self.IndexCells,
            .FreeNodes = self.IndexCells - layout.INDEX_RESERVED_NODES,
            .Reserved1 = 0,
            .ClumpSize = self.CellSize,
            .BTreeType = 0,
            .KeyCompareType = layout.KEY_COMPARE_TYPE,
            .Attributes = 0,
            .Reserved2 = [_]u8{0} ** 64,
        };

        const descriptor_size = @sizeOf(BTreeNodeDescriptor);
        @memcpy(index_buffer[0..descriptor_size], std.mem.asBytes(&node_descriptor));
        @memcpy(index_buffer[descriptor_size .. descriptor_size + @sizeOf(BTreeHeaderRecord)], std.mem.asBytes(&header_record));

        var leaf_node = BTreeNodeDescriptor{
            .ForwardLink = 0,
            .BackwardLink = 0,
            .NodeType = afs.constants.btree.NODE_TYPE_LEAF,
            .Height = 1,
            .RecordCount = 0,
            .Reserved = 0,
        };

        const leaf_offset = self.CellSize;
        @memcpy(index_buffer[leaf_offset .. leaf_offset + @sizeOf(BTreeNodeDescriptor)], std.mem.asBytes(&leaf_node));
    }

    fn writeIndexRecord(
        self: *Self,
        index_buffer: []u8,
        parent_node_id: u32,
        identity: []const u8,
        record_data: []const u8,
    ) !void {
        const leaf_offset = afs.constants.sizes.DEFAULT_CELL_SIZE;
        const node_size = afs.constants.sizes.DEFAULT_CELL_SIZE;
        const record_offset_in_node = self.IndexRecordOffset;
        const record_start = leaf_offset + record_offset_in_node;

        var key = afs.write.stack.createIndexKey(parent_node_id, identity);
        _ = &key;

        const key_size = afs.write.stack.indexKeySize(identity.len);
        @memcpy(index_buffer[record_start .. record_start + key_size], std.mem.asBytes(&key)[0..key_size]);
        @memcpy(index_buffer[record_start + key_size .. record_start + key_size + record_data.len], record_data);

        const node_descriptor: *BTreeNodeDescriptor = @ptrCast(@alignCast(&index_buffer[leaf_offset]));
        const record_index = node_descriptor.RecordCount;

        const offset_entry = leaf_offset + node_size - (@as(usize, record_index) + 1) * @sizeOf(u16);
        std.mem.writeInt(u16, index_buffer[offset_entry..][0..@sizeOf(u16)], @intCast(record_offset_in_node), .little);

        self.IndexRecordOffset += key_size + record_data.len;
        node_descriptor.RecordCount += 1;
    }

    fn writeIndex(self: *Self, index_buffer: []u8) !void {
        const byte_offset = self.PartitionStartByte + @as(u64, self.IndexStartCell) * self.CellSize;
        try self.File.seekTo(byte_offset);
        try self.File.writeAll(index_buffer);
    }

    fn writeCell(self: *Self, cell_number: u32, data: []const u8) !void {
        const byte_offset = self.PartitionStartByte + @as(u64, cell_number) * self.CellSize;
        try self.File.seekTo(byte_offset);
        try self.File.writeAll(data[0..self.CellSize]);
    }

    fn writeJournalInfo(self: *Self) !void {
        var info = JournalInfoCell{
            .Flags = 0,
            .DeviceSignature = [_]u32{0} ** 32,
            .Offset = @as(u64, self.JournalStartCell) * self.CellSize,
            .Size = @as(u64, self.JournalCells) * self.CellSize,
            .Reserved = [_]u8{0} ** 128,
        };

        var buffer: [afs.constants.sizes.DEFAULT_CELL_SIZE]u8 = [_]u8{0} ** afs.constants.sizes.DEFAULT_CELL_SIZE;
        @memcpy(buffer[0..@sizeOf(JournalInfoCell)], std.mem.asBytes(&info));

        try self.writeCell(@intCast(afs.constants.sizes.JOURNAL_INFO_CELL), &buffer);
    }

    fn writeJournalHeader(self: *Self) !void {
        const journal_size = @as(u64, self.JournalCells) * self.CellSize;

        var header = JournalHeader{
            .Magic = afs.constants.magic.JOURNAL_SIGNATURE,
            .Endian = afs.constants.magic.JOURNAL_ENDIAN_MARKER,
            .Start = 0,
            .End = 0,
            .Size = journal_size,
            .CellSize = self.CellSize,
            .ChecksumType = 0,
            .Checksum = 0,
            .Sequence = layout.JOURNAL_INITIAL_SEQUENCE,
        };

        var buffer: [afs.constants.sizes.DEFAULT_CELL_SIZE]u8 = [_]u8{0} ** afs.constants.sizes.DEFAULT_CELL_SIZE;
        @memcpy(buffer[0..@sizeOf(JournalHeader)], std.mem.asBytes(&header));

        try self.writeCell(self.JournalStartCell, &buffer);
    }

    fn writeAllocationMap(self: *Self) !void {
        const bitmap_size = afs.write.allocate.bitmapSize(self.TotalCells);
        const bitmap = try self.Allocator.alloc(u8, self.AllocationMapCells * self.CellSize);
        defer self.Allocator.free(bitmap);

        var map = afs.write.allocate.AllocationMap.init(bitmap, self.TotalCells, 0);
        @memset(bitmap, 0);
        map.reserveRange(0, self.NextCell);

        const byte_offset = self.PartitionStartByte + @as(u64, self.AllocationMapStartCell) * self.CellSize;
        try self.File.seekTo(byte_offset);
        try self.File.writeAll(bitmap[0..@min(bitmap.len, bitmap_size)]);
    }

    fn writeVolumeHeader(self: *Self) !void {
        const timestamp = @as(u64, @intCast(std.time.timestamp()));

        var header = VolumeHeader{
            .Signature = afs.constants.magic.SIGNATURE,
            .Version = afs.constants.magic.VERSION,
            .Attributes = 0,
            .LastBindTimestamp = timestamp,
            .LastCheckTimestamp = timestamp,
            .CreationTimestamp = timestamp,
            .ModificationTimestamp = timestamp,
            .BackupTimestamp = 0,
            .CheckedTimestamp = timestamp,
            .UnitCount = self.UnitCount,
            .StackCount = self.StackCount,
            .CellSize = self.CellSize,
            .TotalCells = self.TotalCells,
            .FreeCells = self.TotalCells - self.NextCell,
            .NextNodeId = self.NextNodeId,
            .WriteCount = 1,
            .EncodingBitmap = 0,
            .AllocationMapSize = self.AllocationMapCells * self.CellSize,
            .AllocationMapClump = self.CellSize,
            .IndexNodeSize = self.CellSize,
            .IndexTotalNodes = self.IndexCells,
            .IndexFreeNodes = self.IndexCells - layout.INDEX_RESERVED_NODES,
            .IndexClumpSize = self.CellSize,
            .IndexRootNode = 1,
            .IndexFirstLeaf = 1,
            .IndexLastLeaf = 1,
            .IndexDepth = 1,
            .IndexRecordCount = self.UnitCount + self.StackCount,
            .SpanOverflowNodeSize = self.CellSize,
            .SpanOverflowTotalNodes = 0,
            .SpanOverflowFreeNodes = 0,
            .SpanOverflowClumpSize = 0,
            .SpanOverflowRootNode = 0,
            .SpanOverflowFirstLeaf = 0,
            .SpanOverflowLastLeaf = 0,
            .SpanOverflowDepth = 0,
            .SpanOverflowRecordCount = 0,
            .AttributesNodeSize = self.CellSize,
            .AttributesTotalNodes = 0,
            .AttributesFreeNodes = 0,
            .AttributesClumpSize = 0,
            .AttributesRootNode = 0,
            .AttributesFirstLeaf = 0,
            .AttributesLastLeaf = 0,
            .AttributesDepth = 0,
            .AttributesRecordCount = 0,
            .AllocationMapSpan = .{
                .StartCell = self.AllocationMapStartCell,
                .CellCount = self.AllocationMapCells,
            },
            .IndexSpan = .{
                .StartCell = self.IndexStartCell,
                .CellCount = self.IndexCells,
            },
            .SpanOverflowSpan = .{},
            .AttributesSpan = .{},
            .StartupSpan = .{},
            .JournalInfoCell = afs.constants.sizes.JOURNAL_INFO_CELL,
            .JournalInfoSize = afs.constants.sizes.JOURNAL_HEADER_SIZE,
            .CompressionType = afs.constants.flags.COMPRESSION_NONE,
            .EncryptionType = afs.constants.flags.ENCRYPTION_NONE,
            .Reserved = [_]u8{0} ** 64,
        };

        var buffer: [afs.constants.sizes.DEFAULT_CELL_SIZE]u8 = [_]u8{0} ** afs.constants.sizes.DEFAULT_CELL_SIZE;
        @memcpy(buffer[0..@sizeOf(VolumeHeader)], std.mem.asBytes(&header));

        try self.writeCell(@intCast(afs.constants.sizes.VOLUME_HEADER_CELL), &buffer);
    }

    fn writeAlternateVolumeHeader(self: *Self) !void {
        var buffer: [afs.constants.sizes.DEFAULT_CELL_SIZE]u8 = undefined;
        try self.File.seekTo(self.PartitionStartByte);
        _ = try self.File.read(&buffer);

        try self.writeCell(1, &buffer);
    }
};
