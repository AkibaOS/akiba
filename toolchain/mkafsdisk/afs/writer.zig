//! AFS Writer for mkafsdisk
//! Creates AFS filesystem structures on disk

const std = @import("std");
const constants = @import("constants.zig");
const types = @import("types.zig");

pub const Writer = struct {
    file: std.fs.File,
    partition_start_byte: u64,
    partition_size_bytes: u64,
    cell_size: u32,
    total_cells: u32,
    allocator: std.mem.Allocator,

    next_cell: u32,
    next_node_id: u32,
    unit_count: u32,
    stack_count: u32,

    allocation_map_start_cell: u32,
    allocation_map_cells: u32,
    index_start_cell: u32,
    index_cells: u32,
    journal_start_cell: u32,
    journal_cells: u32,
    data_start_cell: u32,

    const Self = @This();

    pub fn initialize(
        file: std.fs.File,
        partition_start_byte: u64,
        partition_size_bytes: u64,
        allocator: std.mem.Allocator,
    ) Self {
        const cell_size = constants.default_cell_size;
        const total_cells: u32 = @intCast(partition_size_bytes / cell_size);

        // Layout:
        // Cell 0: Volume Header
        // Cell 1: Alternate Volume Header
        // Cell 2: Journal Info
        // Cells 3-10: Journal (8 cells = 32KB)
        // Cells 11-14: Allocation Map (4 cells for up to 128K cells)
        // Cells 15-30: Index B-tree (16 cells)
        // Cells 31+: Data

        const allocation_map_start: u32 = 11;
        const allocation_map_cells: u32 = 4;
        const index_start: u32 = allocation_map_start + allocation_map_cells;
        const index_cells: u32 = 16;
        const journal_start: u32 = 3;
        const journal_cells: u32 = 8;
        const data_start: u32 = index_start + index_cells;

        return Self{
            .file = file,
            .partition_start_byte = partition_start_byte,
            .partition_size_bytes = partition_size_bytes,
            .cell_size = cell_size,
            .total_cells = total_cells,
            .allocator = allocator,
            .next_cell = data_start,
            .next_node_id = constants.first_user_node_id,
            .unit_count = 0,
            .stack_count = 0,
            .allocation_map_start_cell = allocation_map_start,
            .allocation_map_cells = allocation_map_cells,
            .index_start_cell = index_start,
            .index_cells = index_cells,
            .journal_start_cell = journal_start,
            .journal_cells = journal_cells,
            .data_start_cell = data_start,
        };
    }

    pub fn create_filesystem(self: *Self, source_directory: []const u8) !void {
        std.debug.print("  Creating AFS filesystem...\n", .{});
        std.debug.print("    Total cells: {d}\n", .{self.total_cells});
        std.debug.print("    Cell size: {d}\n", .{self.cell_size});

        try self.write_journal_info();
        try self.write_journal_header();

        const index_buffer = try self.allocator.alloc(u8, self.index_cells * self.cell_size);
        defer self.allocator.free(index_buffer);
        @memset(index_buffer, 0);

        try self.write_index_header(index_buffer);

        const origin_node_id = constants.special_node_id_origin_stack;
        try self.add_stack_to_index(
            index_buffer,
            origin_node_id,
            constants.special_node_id_origin,
            "",
        );
        self.stack_count += 1;

        try self.copy_directory_recursive(source_directory, origin_node_id, index_buffer);

        try self.write_index(index_buffer);
        try self.write_allocation_map();
        try self.write_volume_header();
        try self.write_alternate_volume_header();

        std.debug.print("    Units: {d}, Stacks: {d}\n", .{ self.unit_count, self.stack_count });
        std.debug.print("    Free cells: {d}\n", .{self.total_cells - self.next_cell});
    }

    fn copy_directory_recursive(
        self: *Self,
        source_path: []const u8,
        parent_node_id: u32,
        index_buffer: []u8,
    ) !void {
        var source_dir = std.fs.cwd().openDir(source_path, .{ .iterate = true }) catch |err| {
            std.debug.print("    Warning: Cannot open {s}: {}\n", .{ source_path, err });
            return;
        };
        defer source_dir.close();

        var iterator = source_dir.iterate();
        while (try iterator.next()) |entry| {
            if (entry.name[0] == '.') continue;

            const node_id = self.next_node_id;
            self.next_node_id += 1;

            if (entry.kind == .directory) {
                try self.add_stack_to_index(index_buffer, node_id, parent_node_id, entry.name);
                self.stack_count += 1;

                const sub_path = try std.fs.path.join(self.allocator, &.{ source_path, entry.name });
                defer self.allocator.free(sub_path);

                std.debug.print("    Added stack: {s}/\n", .{entry.name});
                try self.copy_directory_recursive(sub_path, node_id, index_buffer);
            } else {
                const unit_path = try std.fs.path.join(self.allocator, &.{ source_path, entry.name });
                defer self.allocator.free(unit_path);

                try self.add_unit_to_index(index_buffer, node_id, parent_node_id, entry.name, unit_path);
                self.unit_count += 1;

                std.debug.print("    Added unit: {s}\n", .{entry.name});
            }
        }
    }

    fn add_stack_to_index(
        self: *Self,
        index_buffer: []u8,
        node_id: u32,
        parent_node_id: u32,
        identity: []const u8,
    ) !void {
        const timestamp = @as(u64, @intCast(std.time.timestamp()));

        var record = types.StackRecord{
            .record_type = constants.index_record_type_stack,
            .flags = constants.unit_flag_has_thread,
            .valence = 0,
            .node_id = node_id,
            .creation_timestamp = timestamp,
            .modification_timestamp = timestamp,
            .attribute_modification_timestamp = timestamp,
            .access_timestamp = timestamp,
            .backup_timestamp = 0,
            .permissions = .{
                .owner_id = 0,
                .group_id = 0,
                .admin_flags = 0,
                .owner_flags = 0,
                .mode = 0o755,
                .inode_or_link = 0,
            },
            .special = [_]u8{0} ** 16,
            .text_encoding = 0,
            .reserved = 0,
        };

        try self.write_index_record(index_buffer, parent_node_id, identity, std.mem.asBytes(&record));
    }

    fn add_unit_to_index(
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
        const cells_needed = if (file_size == 0) 0 else @as(u32, @intCast((file_size + self.cell_size - 1) / self.cell_size));

        const start_cell = self.next_cell;
        self.next_cell += cells_needed;

        if (cells_needed > 0) {
            var remaining = file_size;
            var current_cell = start_cell;
            var buffer = try self.allocator.alloc(u8, self.cell_size);
            defer self.allocator.free(buffer);

            while (remaining > 0) {
                @memset(buffer, 0);
                const to_read = @min(remaining, self.cell_size);
                const bytes_read = try source_file.read(buffer[0..to_read]);
                if (bytes_read == 0) break;

                try self.write_cell(current_cell, buffer);
                remaining -= bytes_read;
                current_cell += 1;
            }
        }

        const timestamp = @as(u64, @intCast(std.time.timestamp()));

        var record = types.UnitRecord{
            .record_type = constants.index_record_type_unit,
            .flags = constants.unit_flag_has_thread,
            .reserved1 = 0,
            .node_id = node_id,
            .creation_timestamp = timestamp,
            .modification_timestamp = timestamp,
            .attribute_modification_timestamp = timestamp,
            .access_timestamp = timestamp,
            .backup_timestamp = 0,
            .permissions = .{
                .owner_id = 0,
                .group_id = 0,
                .admin_flags = 0,
                .owner_flags = 0,
                .mode = 0o644,
                .inode_or_link = 0,
            },
            .special = [_]u8{0} ** 16,
            .text_encoding = 0,
            .reserved2 = 0,
            .data_channel = .{
                .logical_size = file_size,
                .physical_size = @as(u64, cells_needed) * self.cell_size,
                .clump_size = self.cell_size,
                .total_cells = cells_needed,
                .spans = blk: {
                    var spans: [constants.span_inline_count]types.SpanDescriptor = [_]types.SpanDescriptor{.{}} ** constants.span_inline_count;
                    if (cells_needed > 0) {
                        spans[0] = .{
                            .start_cell = start_cell,
                            .cell_count = cells_needed,
                        };
                    }
                    break :blk spans;
                },
            },
            .resource_channel = .{},
        };

        try self.write_index_record(index_buffer, parent_node_id, identity, std.mem.asBytes(&record));
    }

    fn write_index_header(self: *Self, index_buffer: []u8) !void {
        var node_descriptor = types.BTreeNodeDescriptor{
            .forward_link = 0,
            .backward_link = 0,
            .node_type = constants.btree_node_type_header,
            .height = 0,
            .record_count = 3,
            .reserved = 0,
        };

        const header_record = types.BTreeHeaderRecord{
            .depth = 1,
            .root_node = 1,
            .leaf_record_count = 0,
            .first_leaf_node = 1,
            .last_leaf_node = 1,
            .node_size = @intCast(self.cell_size),
            .max_key_length = 518,
            .total_nodes = self.index_cells,
            .free_nodes = self.index_cells - 2,
            .reserved1 = 0,
            .clump_size = self.cell_size,
            .btree_type = 0,
            .key_compare_type = 0xCF,
            .attributes = 0,
            .reserved2 = [_]u8{0} ** 64,
        };

        @memcpy(index_buffer[0..@sizeOf(types.BTreeNodeDescriptor)], std.mem.asBytes(&node_descriptor));
        @memcpy(index_buffer[14 .. 14 + @sizeOf(types.BTreeHeaderRecord)], std.mem.asBytes(&header_record));

        var leaf_node = types.BTreeNodeDescriptor{
            .forward_link = 0,
            .backward_link = 0,
            .node_type = constants.btree_node_type_leaf,
            .height = 1,
            .record_count = 0,
            .reserved = 0,
        };

        const leaf_offset = self.cell_size;
        @memcpy(index_buffer[leaf_offset .. leaf_offset + @sizeOf(types.BTreeNodeDescriptor)], std.mem.asBytes(&leaf_node));
    }

    var index_record_offset: usize = 14;

    fn write_index_record(
        self: *Self,
        index_buffer: []u8,
        parent_node_id: u32,
        identity: []const u8,
        record_data: []const u8,
    ) !void {
        _ = self;

        const leaf_offset = constants.default_cell_size;
        const record_start = leaf_offset + 14 + index_record_offset;

        var key = types.IndexKey{
            .key_length = @intCast(6 + identity.len * 2),
            .parent_node_id = parent_node_id,
            .identity = [_]u16{0} ** 256,
        };

        for (identity, 0..) |char, i| {
            key.identity[i] = char;
        }

        const key_size = 6 + identity.len * 2;
        @memcpy(index_buffer[record_start .. record_start + key_size], std.mem.asBytes(&key)[0..key_size]);
        @memcpy(index_buffer[record_start + key_size .. record_start + key_size + record_data.len], record_data);

        index_record_offset += key_size + record_data.len;

        var node_desc: *types.BTreeNodeDescriptor = @ptrCast(@alignCast(&index_buffer[leaf_offset]));
        node_desc.record_count += 1;
    }

    fn write_index(self: *Self, index_buffer: []u8) !void {
        const byte_offset = self.partition_start_byte + @as(u64, self.index_start_cell) * self.cell_size;
        try self.file.seekTo(byte_offset);
        try self.file.writeAll(index_buffer);
    }

    fn write_cell(self: *Self, cell_number: u32, data: []const u8) !void {
        const byte_offset = self.partition_start_byte + @as(u64, cell_number) * self.cell_size;
        try self.file.seekTo(byte_offset);
        try self.file.writeAll(data[0..self.cell_size]);
    }

    fn write_journal_info(self: *Self) !void {
        var info = types.JournalInfoCell{
            .flags = 0,
            .device_signature = [_]u32{0} ** 32,
            .offset = @as(u64, self.journal_start_cell) * self.cell_size,
            .size = @as(u64, self.journal_cells) * self.cell_size,
            .reserved = [_]u8{0} ** 128,
        };

        var buffer: [4096]u8 = [_]u8{0} ** 4096;
        @memcpy(buffer[0..@sizeOf(types.JournalInfoCell)], std.mem.asBytes(&info));

        try self.write_cell(2, &buffer);
    }

    fn write_journal_header(self: *Self) !void {
        const journal_size = @as(u64, self.journal_cells) * self.cell_size;

        var header = types.JournalHeader{
            .magic = constants.journal_signature,
            .endian = 0x12345678,
            .start = 0,
            .end = 0,
            .size = journal_size,
            .cell_size = self.cell_size,
            .checksum_type = 0,
            .checksum = 0,
            .sequence = 1,
        };

        var buffer: [4096]u8 = [_]u8{0} ** 4096;
        @memcpy(buffer[0..@sizeOf(types.JournalHeader)], std.mem.asBytes(&header));

        try self.write_cell(self.journal_start_cell, &buffer);
    }

    fn write_allocation_map(self: *Self) !void {
        const bitmap_size = (self.total_cells + 7) / 8;
        var bitmap = try self.allocator.alloc(u8, self.allocation_map_cells * self.cell_size);
        defer self.allocator.free(bitmap);
        @memset(bitmap, 0);

        var i: u32 = 0;
        while (i < self.next_cell) : (i += 1) {
            const byte_index = i / 8;
            const bit_index: u3 = @intCast(i % 8);
            bitmap[byte_index] |= @as(u8, 1) << bit_index;
        }

        const byte_offset = self.partition_start_byte + @as(u64, self.allocation_map_start_cell) * self.cell_size;
        try self.file.seekTo(byte_offset);
        try self.file.writeAll(bitmap[0..@min(bitmap.len, bitmap_size)]);
    }

    fn write_volume_header(self: *Self) !void {
        const timestamp = @as(u64, @intCast(std.time.timestamp()));

        var header = types.VolumeHeader{
            .signature = constants.signature,
            .version = constants.version,
            .attributes = 0,
            .last_bind_timestamp = timestamp,
            .last_check_timestamp = timestamp,
            .creation_timestamp = timestamp,
            .modification_timestamp = timestamp,
            .backup_timestamp = 0,
            .checked_timestamp = timestamp,
            .unit_count = self.unit_count,
            .stack_count = self.stack_count,
            .cell_size = self.cell_size,
            .total_cells = self.total_cells,
            .free_cells = self.total_cells - self.next_cell,
            .next_node_id = self.next_node_id,
            .write_count = 1,
            .encoding_bitmap = 0,
            .allocation_map_size = self.allocation_map_cells * self.cell_size,
            .allocation_map_clump = self.cell_size,
            .index_node_size = self.cell_size,
            .index_total_nodes = self.index_cells,
            .index_free_nodes = self.index_cells - 2,
            .index_clump_size = self.cell_size,
            .index_root_node = 1,
            .index_first_leaf = 1,
            .index_last_leaf = 1,
            .index_depth = 1,
            .index_record_count = self.unit_count + self.stack_count,
            .span_overflow_node_size = self.cell_size,
            .span_overflow_total_nodes = 0,
            .span_overflow_free_nodes = 0,
            .span_overflow_clump_size = 0,
            .span_overflow_root_node = 0,
            .span_overflow_first_leaf = 0,
            .span_overflow_last_leaf = 0,
            .span_overflow_depth = 0,
            .span_overflow_record_count = 0,
            .attributes_node_size = self.cell_size,
            .attributes_total_nodes = 0,
            .attributes_free_nodes = 0,
            .attributes_clump_size = 0,
            .attributes_root_node = 0,
            .attributes_first_leaf = 0,
            .attributes_last_leaf = 0,
            .attributes_depth = 0,
            .attributes_record_count = 0,
            .allocation_map_span = .{
                .start_cell = self.allocation_map_start_cell,
                .cell_count = self.allocation_map_cells,
            },
            .index_span = .{
                .start_cell = self.index_start_cell,
                .cell_count = self.index_cells,
            },
            .span_overflow_span = .{},
            .attributes_span = .{},
            .startup_span = .{},
            .journal_info_cell = constants.journal_info_cell,
            .journal_info_size = constants.journal_header_size,
            .compression_type = constants.compression_none,
            .encryption_type = constants.encryption_none,
            .reserved = [_]u8{0} ** 64,
        };

        var buffer: [4096]u8 = [_]u8{0} ** 4096;
        @memcpy(buffer[0..@sizeOf(types.VolumeHeader)], std.mem.asBytes(&header));

        try self.write_cell(0, &buffer);
    }

    fn write_alternate_volume_header(self: *Self) !void {
        var buffer: [4096]u8 = undefined;
        try self.file.seekTo(self.partition_start_byte);
        _ = try self.file.read(&buffer);

        try self.write_cell(1, &buffer);
    }
};
