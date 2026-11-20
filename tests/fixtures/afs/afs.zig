//! Read Only Catalog And Data Cells For The Persona Fixture

const std = @import("std");

const afs = @import("shared").afs;
const geometry = @import("tests").fixtures.constants.catalog;
const names = @import("tests").fixtures.strings.catalog;

const BlockError = afs.errors.block.BlockError;
const BlockReader = afs.types.block.BlockReader;
const Header = afs.types.btree.records.HeaderRecord;
const IndexKey = afs.types.btree.records.IndexKey;
const LibraryCells = @import("tests").fixtures.types.catalog.LibraryCells;
const Node = afs.types.btree.records.NodeDescriptor;
const Volume = afs.types.volume.VolumeHeader;

pub fn device(cells: *LibraryCells, library_bytes: []const u8, identity: []const u8, missing: bool) !BlockReader {
    cells.* = .{
        .Bytes = library_bytes,
        .Identity = identity,
        .Missing = missing,
        .PayloadCells = try afs.write.unit.cellsNeeded(library_bytes.len, geometry.CELL_SIZE),
    };
    return .{ .Context = cells, .ReadFn = read, .CellSize = geometry.CELL_SIZE, .TotalCells = total(cells) };
}

fn read(context: *anyopaque, cell: u64, destination: []u8) BlockError!void {
    const cells: *const LibraryCells = @ptrCast(@alignCast(context));
    if (cell >= total(cells)) return error.OutOfBounds;
    if (destination.len != geometry.CELL_SIZE) return error.InvalidCell;
    @memset(destination, 0);
    switch (cell) {
        0 => volume(cells, destination),
        geometry.CATALOG_START => header(cells, destination),
        geometry.LEAF_CELL => leaf(cells, destination) catch return error.DeviceError,
        else => {
            const start: usize = @intCast((cell - geometry.DATA_START) % cells.PayloadCells * geometry.CELL_SIZE);
            const length = @min(destination.len, cells.Bytes.len - start);
            @memcpy(destination[0..length], cells.Bytes[start..][0..length]);
        },
    }
}

fn total(cells: *const LibraryCells) u64 {
    return geometry.DATA_START + 2 * @as(u64, cells.PayloadCells);
}

fn records(cells: *const LibraryCells) u16 {
    return if (cells.Missing) geometry.MISSING_RECORDS else geometry.PRESENT_RECORDS;
}

fn volume(cells: *const LibraryCells, destination: []u8) void {
    const value: Volume = .{
        .UnitCount = if (cells.Missing) 1 else 2,
        .StackCount = geometry.STACK_COUNT,
        .TotalCells = @intCast(total(cells)),
        .FreeCells = if (cells.Missing) cells.PayloadCells else 0,
        .IndexTotalNodes = geometry.NODE_COUNT,
        .IndexRecordCount = records(cells),
        .IndexSpan = .{ .StartCell = geometry.CATALOG_START, .CellCount = geometry.NODE_COUNT },
    };
    @memcpy(destination[0..@sizeOf(Volume)], std.mem.asBytes(&value));
}

fn header(cells: *const LibraryCells, destination: []u8) void {
    const node: Node = .{ .NodeType = afs.constants.btree.records.NODE_TYPE_HEADER, .RecordCount = 1 };
    @memcpy(destination[0..@sizeOf(Node)], std.mem.asBytes(&node));
    const value: Header = .{ .NodeSize = geometry.CELL_SIZE, .TotalNodes = geometry.NODE_COUNT, .LeafRecordCount = records(cells) };
    @memcpy(destination[@sizeOf(Node)..][0..@sizeOf(Header)], std.mem.asBytes(&value));
    offset(destination, 0, @sizeOf(Node));
}

fn leaf(cells: *const LibraryCells, destination: []u8) !void {
    const origin = afs.constants.nodes;
    const node: Node = .{ .Height = 1, .RecordCount = records(cells) };
    @memcpy(destination[0..@sizeOf(Node)], std.mem.asBytes(&node));
    var position: usize = @sizeOf(Node);
    try add(destination, &position, 0, origin.ORIGIN, names.ROOT, afs.write.stack.createStackRecord(origin.ORIGIN_STACK, 0, geometry.STACK_MODE));
    try add(destination, &position, 1, origin.ORIGIN_STACK, names.LIBRARIES, afs.write.stack.createStackRecord(geometry.INSTALLED_ID, 0, geometry.STACK_MODE));
    try add(destination, &position, 2, origin.ORIGIN_STACK, names.SYSTEM, afs.write.stack.createStackRecord(geometry.SYSTEM_ID, 0, geometry.STACK_MODE));
    try add(destination, &position, 3, geometry.SYSTEM_ID, names.LIBRARIES, afs.write.stack.createStackRecord(geometry.SYSTEM_LIBRARIES_ID, 0, geometry.STACK_MODE));
    const author = try afs.write.unit.createChannelInfo(cells.Bytes.len, geometry.DATA_START, cells.PayloadCells, geometry.CELL_SIZE);
    try add(destination, &position, 4, geometry.INSTALLED_ID, cells.Identity, afs.write.stack.createUnitRecord(geometry.AUTHOR_UNIT_ID, 0, geometry.UNIT_MODE, author));
    if (!cells.Missing) {
        const system = try afs.write.unit.createChannelInfo(cells.Bytes.len, geometry.DATA_START + cells.PayloadCells, cells.PayloadCells, geometry.CELL_SIZE);
        try add(destination, &position, 5, geometry.SYSTEM_LIBRARIES_ID, cells.Identity, afs.write.stack.createUnitRecord(geometry.SYSTEM_UNIT_ID, 0, geometry.UNIT_MODE, system));
    }
}

fn add(destination: []u8, position: *usize, index: usize, parent: u32, name: []const u8, record: anytype) !void {
    const key = try afs.write.stack.createIndexKey(parent, name);
    const limit = destination.len - @as(usize, geometry.PRESENT_RECORDS) * @sizeOf(u16);
    if (position.* + key.KeyLength + @sizeOf(@TypeOf(record)) > limit) return error.InvalidFixture;
    offset(destination, index, position.*);
    const key_bytes = destination[position.*..][0..key.KeyLength];
    std.mem.writeInt(u16, key_bytes[0..@sizeOf(u16)], key.KeyLength, .little);
    std.mem.writeInt(u32, key_bytes[@offsetOf(IndexKey, "ParentNodeId")..][0..@sizeOf(u32)], key.ParentNodeId, .little);
    for (name, 0..) |_, character| {
        const start = afs.constants.btree.records.INDEX_KEY_HEADER_SIZE + character * @sizeOf(u16);
        std.mem.writeInt(u16, key_bytes[start..][0..@sizeOf(u16)], key.Identity[character], .little);
    }
    position.* += key.KeyLength;
    const bytes = std.mem.asBytes(&record);
    @memcpy(destination[position.*..][0..bytes.len], bytes);
    position.* += bytes.len;
}

fn offset(destination: []u8, index: usize, value: usize) void {
    const start = destination.len - (index + 1) * @sizeOf(u16);
    std.mem.writeInt(u16, destination[start..][0..@sizeOf(u16)], @intCast(value), .little);
}
