//! Planned AFS Disk Emission

const std = @import("std");

const afs = @import("shared").afs;
const tool = @import("mkafsdisk");

const Entry = tool.types.catalog.Entry;
const FilesystemPlan = tool.types.filesystem.FilesystemPlan;
const PlanningError = tool.errors.planning.PlanningError;
const SpanDescriptor = afs.types.volume.SpanDescriptor;
const VolumeHeader = afs.types.volume.VolumeHeader;

const messages = tool.strings.messages;

pub const Writer = struct {
    File: std.fs.File,
    PartitionStartByte: u64,
    PartitionSizeBytes: u64,
    Allocator: std.mem.Allocator,
    CellSize: u32 = afs.constants.sizes.DEFAULT_CELL_SIZE,
    TotalCells: u32 = 0,
    ImageSizeBytes: u64 = 0,
    IO: ?tool.types.io.Operations = null,

    const Self = @This();

    pub fn initialize(
        file: std.fs.File,
        partition_start_byte: u64,
        partition_size_bytes: u64,
        allocator: std.mem.Allocator,
    ) Self {
        return .{
            .File = file,
            .PartitionStartByte = partition_start_byte,
            .PartitionSizeBytes = partition_size_bytes,
            .Allocator = allocator,
        };
    }

    pub fn createFilesystem(self: *Self, source_location: []const u8) !void {
        var plan = try tool.catalog.prepare.prepare(self.Allocator, source_location, self.PartitionSizeBytes);
        defer plan.deinit();
        try self.writeFilesystem(&plan);
    }

    pub fn writeFilesystem(self: *Self, plan: *const FilesystemPlan) !void {
        try self.validatePlan(plan);
        std.debug.print(messages.AFS_CREATING, .{});
        std.debug.print(messages.AFS_TOTAL_CELLS, .{self.TotalCells});
        std.debug.print(messages.AFS_CELL_SIZE, .{self.CellSize});
        for (plan.Manifest.Entries, plan.Spans) |entry, span| {
            if (entry.Kind != .Unit) continue;
            try self.copyUnit(entry, span);
            std.debug.print(messages.AFS_ADDED_UNIT, .{entry.Identity});
        }
        try self.writeIndex(plan);
        try self.writeAllocationMap(plan);
        try self.writeVolumeHeaders(plan);
        std.debug.print(messages.AFS_COUNTS, .{ plan.Manifest.UnitCount, plan.Manifest.StackCount });
        std.debug.print(messages.AFS_FREE_CELLS, .{plan.Volume.FreeCells});
    }

    fn validatePlan(self: *Self, plan: *const FilesystemPlan) !void {
        if (self.CellSize != afs.constants.sizes.DEFAULT_CELL_SIZE or plan.Manifest.Entries.len == 0) return PlanningError.InvalidGeometry;
        const total_cells = self.PartitionSizeBytes / self.CellSize;
        if (plan.Volume.UsedCells < plan.Volume.DataStartCell or plan.Volume.TotalCells != total_cells or
            plan.Manifest.Entries.len != plan.Spans.len or plan.Tree.Nodes.len != plan.Tree.Header.TotalNodes or
            plan.Tree.Header.LeafRecordCount != plan.Manifest.Entries.len)
        {
            return PlanningError.InvalidGeometry;
        }
        const checked = try tool.image.geometry.volume(total_cells, plan.Tree.Header.TotalNodes, plan.Volume.UsedCells - plan.Volume.DataStartCell);
        if (!std.meta.eql(checked, plan.Volume)) return PlanningError.InvalidGeometry;
        self.ImageSizeBytes = try self.File.getEndPos();
        const partition_end = std.math.add(u64, self.PartitionStartByte, self.PartitionSizeBytes) catch return PlanningError.Overflow;
        if (partition_end > self.ImageSizeBytes) return PlanningError.OutOfSpace;
        self.TotalCells = plan.Volume.TotalCells;
    }

    fn copyUnit(self: *Self, entry: Entry, span: SpanDescriptor) !void {
        const source = try std.fs.cwd().openFile(entry.Path, .{});
        defer source.close();
        const initial = try source.stat();
        if (initial.kind != .file or initial.size != entry.LogicalSize) return tool.errors.image.ImageError.SourceChanged;
        var remaining = entry.LogicalSize;
        var current_cell = span.StartCell;
        var buffer: [afs.constants.sizes.DEFAULT_CELL_SIZE]u8 = undefined;
        const operations = self.IO orelse tool.image.io.native();
        while (remaining > 0) {
            @memset(&buffer, 0);
            const to_read: usize = @intCast(@min(remaining, self.CellSize));
            try tool.image.io.readExact(operations, source, buffer[0..to_read]);
            try self.writeCell(current_cell, &buffer);
            remaining -= to_read;
            current_cell += 1;
        }
        const final = try source.stat();
        if (final.kind != .file or final.size != entry.LogicalSize or final.mtime != initial.mtime) return tool.errors.image.ImageError.SourceChanged;
    }

    fn writeIndex(self: *Self, plan: *const FilesystemPlan) !void {
        var buffer: [afs.constants.sizes.DEFAULT_CELL_SIZE]u8 = undefined;
        for (plan.Tree.Nodes, 0..) |_, index| {
            const node_number: u32 = @intCast(index);
            try tool.catalog.encode.encode(&plan.Tree, node_number, plan.Manifest.Entries, plan.Spans, &buffer);
            const cell = @as(u64, plan.Volume.IndexStartCell) + node_number;
            try self.writeCell(cell, &buffer);
        }
    }

    fn writeAllocationMap(self: *Self, plan: *const FilesystemPlan) !void {
        var buffer: [afs.constants.sizes.DEFAULT_CELL_SIZE]u8 = undefined;
        var map_cell: u32 = 0;
        while (map_cell < plan.Volume.BitmapCells) : (map_cell += 1) {
            const byte_start = @as(u64, map_cell) * self.CellSize;
            for (&buffer, 0..) |*byte, index| {
                const first_cell = (byte_start + index) * @bitSizeOf(u8);
                const allocated = if (first_cell < plan.Volume.UsedCells) @min(@bitSizeOf(u8), plan.Volume.UsedCells - first_cell) else 0;
                const valid = if (first_cell < plan.Volume.TotalCells) @min(@bitSizeOf(u8), plan.Volume.TotalCells - first_cell) else 0;
                byte.* = lowBits(@intCast(allocated)) | ~lowBits(@intCast(valid));
            }
            try self.writeCell(@as(u64, plan.Volume.AllocationMapStartCell) + map_cell, &buffer);
        }
    }

    fn writeVolumeHeaders(self: *Self, plan: *const FilesystemPlan) !void {
        const timestamp = plan.Manifest.Entries[0].Timestamp;
        const tree = plan.Tree.Header;
        const header = VolumeHeader{
            .LastBindTimestamp = timestamp,
            .LastCheckTimestamp = timestamp,
            .CreationTimestamp = timestamp,
            .ModificationTimestamp = timestamp,
            .CheckedTimestamp = timestamp,
            .UnitCount = plan.Manifest.UnitCount,
            .StackCount = plan.Manifest.StackCount,
            .CellSize = self.CellSize,
            .TotalCells = plan.Volume.TotalCells,
            .FreeCells = plan.Volume.FreeCells,
            .NextNodeId = plan.Manifest.NextNodeId,
            .AllocationMapSize = plan.Volume.AllocationMapSize,
            .AllocationMapClump = self.CellSize,
            .IndexNodeSize = tree.NodeSize,
            .IndexTotalNodes = tree.TotalNodes,
            .IndexFreeNodes = tree.FreeNodes,
            .IndexClumpSize = tree.ClumpSize,
            .IndexRootNode = tree.RootNode,
            .IndexFirstLeaf = tree.FirstLeafNode,
            .IndexLastLeaf = tree.LastLeafNode,
            .IndexDepth = tree.Depth,
            .IndexRecordCount = tree.LeafRecordCount,
            .AllocationMapSpan = .{ .StartCell = plan.Volume.AllocationMapStartCell, .CellCount = plan.Volume.BitmapCells },
            .IndexSpan = .{ .StartCell = plan.Volume.IndexStartCell, .CellCount = plan.Volume.IndexCells },
        };
        var buffer: [afs.constants.sizes.DEFAULT_CELL_SIZE]u8 = @splat(0);
        tool.catalog.encode.encodeValue(VolumeHeader, header, buffer[0..@sizeOf(VolumeHeader)]);
        try self.writeCell(afs.constants.sizes.VOLUME_HEADER_CELL, &buffer);
        try self.writeCell(afs.constants.sizes.VOLUME_HEADER_CELL + 1, &buffer);
    }

    fn writeCell(self: *Self, cell_number: u64, data: []const u8) !void {
        if (data.len != self.CellSize or cell_number >= self.TotalCells) return PlanningError.OutOfSpace;
        const relative_offset = std.math.mul(u64, cell_number, self.CellSize) catch return PlanningError.Overflow;
        if (relative_offset > self.PartitionSizeBytes or data.len > self.PartitionSizeBytes - relative_offset) return PlanningError.OutOfSpace;
        const offset = std.math.add(u64, self.PartitionStartByte, relative_offset) catch return PlanningError.Overflow;
        if (offset > self.ImageSizeBytes or data.len > self.ImageSizeBytes - offset) return PlanningError.OutOfSpace;
        const operations = self.IO orelse tool.image.io.native();
        try operations.WriteFn(operations.Context, self.File, data, offset);
    }

    fn lowBits(count: u4) u8 {
        return @intCast((@as(u16, 1) << count) - 1);
    }
};
