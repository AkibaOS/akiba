//! Checked Disk And Volume Planning

const std = @import("std");

const afs = @import("shared").afs;
const tool = @import("mkafsdisk");

const layout = tool.constants.disk;
const PlanningError = tool.errors.planning.PlanningError;

pub fn disk(size_mib: u32) PlanningError!tool.types.geometry.DiskPlan {
    const total_bytes = std.math.mul(u64, size_mib, tool.constants.catalog.records.MEBIBYTE_BYTES) catch return PlanningError.Overflow;
    const total_sectors = total_bytes / layout.SECTOR_SIZE;
    const esp_start: u64 = layout.ESP_START_SECTOR;
    const esp_end = esp_start + layout.ESP_SIZE_SECTORS - 1;
    const afs_start = esp_end + 1;
    if (total_sectors < afs_start + layout.GPT_RESERVED_SECTORS) return PlanningError.InvalidGeometry;
    const afs_end = total_sectors - layout.GPT_RESERVED_SECTORS;
    const partition_sectors = afs_end - afs_start + 1;
    const partition_bytes = std.math.mul(u64, partition_sectors, layout.SECTOR_SIZE) catch return PlanningError.Overflow;
    const total_cells = partition_bytes / afs.constants.sizes.DEFAULT_CELL_SIZE;
    if (total_cells == 0) return PlanningError.InvalidGeometry;
    if (total_cells > std.math.maxInt(u32)) return PlanningError.Overflow;
    return .{
        .TotalBytes = total_bytes,
        .TotalSectors = total_sectors,
        .EspStartLBA = esp_start,
        .EspEndLBA = esp_end,
        .AfsStartLBA = afs_start,
        .AfsEndLBA = afs_end,
        .PrimaryHeaderLBA = tool.constants.gpt.HEADER_LBA,
        .PrimaryEntriesLBA = tool.constants.gpt.ENTRIES_START_LBA,
        .BackupHeaderLBA = total_sectors - 1,
        .BackupEntriesLBA = total_sectors - layout.GPT_BACKUP_ENTRIES_SECTORS,
        .FirstUsableLBA = layout.GPT_RESERVED_SECTORS,
        .LastUsableLBA = afs_end,
        .PartitionStartByte = std.math.mul(u64, afs_start, layout.SECTOR_SIZE) catch return PlanningError.Overflow,
        .PartitionSizeBytes = partition_bytes,
        .TotalCells = @intCast(total_cells),
        .ProtectiveSectorCount = @intCast(@min(total_sectors - 1, std.math.maxInt(u32))),
    };
}

pub fn volume(total_cells: u64, tree_nodes: u64, payload_cells: u64) PlanningError!tool.types.geometry.VolumePlan {
    if (total_cells > std.math.maxInt(u32) or tree_nodes > std.math.maxInt(u32) or payload_cells > std.math.maxInt(u32)) {
        return PlanningError.Overflow;
    }
    if (total_cells == 0 or tree_nodes < tool.constants.catalog.records.MINIMUM_TREE_NODES) return PlanningError.InvalidGeometry;
    const cell_size = afs.constants.sizes.DEFAULT_CELL_SIZE;
    const bitmap_bytes = (total_cells - 1) / @bitSizeOf(u8) + 1;
    const bitmap_cells = (bitmap_bytes - 1) / cell_size + 1;
    const map_start: u64 = tool.constants.afs.ALLOCATION_MAP_START_CELL;
    const index_start = std.math.add(u64, map_start, bitmap_cells) catch return PlanningError.Overflow;
    const data_start = std.math.add(u64, index_start, tree_nodes) catch return PlanningError.Overflow;
    const used_cells = std.math.add(u64, data_start, payload_cells) catch return PlanningError.Overflow;
    if (used_cells > total_cells) return PlanningError.OutOfSpace;
    return .{
        .TotalCells = @intCast(total_cells),
        .BitmapBytes = @intCast(bitmap_bytes),
        .BitmapCells = @intCast(bitmap_cells),
        .AllocationMapStartCell = @intCast(map_start),
        .AllocationMapSize = @intCast(bitmap_cells * cell_size),
        .IndexStartCell = @intCast(index_start),
        .IndexCells = @intCast(tree_nodes),
        .DataStartCell = @intCast(data_start),
        .UsedCells = @intCast(used_cells),
        .FreeCells = @intCast(total_cells - used_cells),
    };
}

pub fn payloadCells(logical_size: u64) PlanningError!u32 {
    return afs.write.unit.cellsNeeded(logical_size, afs.constants.sizes.DEFAULT_CELL_SIZE) catch |failure|
        return if (failure == error.InvalidCell) PlanningError.InvalidGeometry else PlanningError.Overflow;
}

pub fn spans(
    allocator: std.mem.Allocator,
    entries: []const tool.types.catalog.entry.Entry,
    plan: tool.types.geometry.VolumePlan,
) (std.mem.Allocator.Error || PlanningError)![]afs.types.volume.SpanDescriptor {
    if (plan.UsedCells < plan.DataStartCell) return PlanningError.InvalidGeometry;
    const checked = try volume(plan.TotalCells, plan.IndexCells, plan.UsedCells - plan.DataStartCell);
    if (!std.meta.eql(checked, plan)) return PlanningError.InvalidGeometry;
    const assigned = try allocator.alloc(afs.types.volume.SpanDescriptor, entries.len);
    errdefer allocator.free(assigned);
    @memset(assigned, .{});
    var next_cell: u64 = plan.DataStartCell;
    for (entries, assigned) |entry, *span| {
        if (entry.Kind == .Stack) {
            if (entry.LogicalSize != 0) return PlanningError.InvalidCatalog;
            continue;
        }
        const count = try payloadCells(entry.LogicalSize);
        if (count > plan.UsedCells - next_cell) return PlanningError.OutOfSpace;
        if (count == 0) continue;
        span.* = .{ .StartCell = next_cell, .CellCount = count };
        next_cell += count;
    }
    if (next_cell != plan.UsedCells) return PlanningError.InvalidGeometry;
    return assigned;
}
