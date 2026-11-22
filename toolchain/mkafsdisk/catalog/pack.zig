//! Pure Bottom Up AFS Catalog Packing

const std = @import("std");

const afs = @import("shared").afs;
const separators = @import("shared").location.constants.separators;
const tool = @import("mkafsdisk");

const Entry = tool.types.catalog.entry.Entry;
const Level = tool.types.tree.Level;
const NodePlan = tool.types.tree.NodePlan;
const PlanningError = tool.errors.planning.PlanningError;
const RecordPlan = tool.types.tree.RecordPlan;

const constants = tool.constants.catalog.records;

pub fn pack(allocator: std.mem.Allocator, entries: []const Entry) (std.mem.Allocator.Error || PlanningError)!tool.types.tree.TreePlan {
    if (entries.len == 0) return PlanningError.InvalidCatalog;
    const record_count = std.math.cast(u32, entries.len) orelse return PlanningError.Overflow;
    for (entries) |entry| try validateEntry(entry);
    const sorted = try allocator.alloc(usize, entries.len);
    defer allocator.free(sorted);
    for (sorted, 0..) |*index, position| index.* = position;
    std.mem.sort(usize, sorted, entries, lessEntry);
    for (sorted[1..], sorted[0 .. sorted.len - 1]) |current, previous| {
        if (compareEntries(entries[previous], entries[current]) == 0) return PlanningError.DuplicateKey;
    }
    var nodes: std.ArrayList(NodePlan) = .empty;
    defer nodes.deinit(allocator);
    errdefer for (nodes.items) |node| allocator.free(node.Records);
    try nodes.append(allocator, .{ .Number = 0, .Height = 0, .Records = &.{} });
    var level = try buildLeaves(allocator, entries, sorted, &nodes);
    const first_leaf: u32 = @intCast(level.Start);
    const last_leaf: u32 = @intCast(level.Start + level.Count - 1);
    while (level.Count > 1) level = try buildParents(allocator, entries, &nodes, level);
    const header = afs.types.btree.records.HeaderRecord{
        .Depth = level.Height,
        .RootNode = @intCast(level.Start),
        .LeafRecordCount = record_count,
        .FirstLeafNode = first_leaf,
        .LastLeafNode = last_leaf,
        .NodeSize = afs.constants.sizes.DEFAULT_CELL_SIZE,
        .MaxKeyLength = constants.MAXIMUM_KEY_BYTES,
        .TotalNodes = @intCast(nodes.items.len),
        .FreeNodes = 0,
        .ClumpSize = afs.constants.sizes.DEFAULT_CELL_SIZE,
        .KeyCompareType = tool.constants.afs.KEY_COMPARE_TYPE,
    };
    return .{ .Allocator = allocator, .Nodes = try nodes.toOwnedSlice(allocator), .Header = header };
}

pub fn validateIdentity(identity: []const u8, allow_empty: bool) PlanningError!void {
    if ((!allow_empty and identity.len == 0) or identity.len > constants.MAXIMUM_IDENTITY_BYTES) return PlanningError.InvalidIdentity;
    for (identity) |character| {
        if (character == constants.IDENTITY_TERMINATOR or character == separators.FORWARD_SLASH or character == separators.BACK_SLASH) {
            return PlanningError.InvalidIdentity;
        }
    }
}

pub fn validateEntry(entry: Entry) PlanningError!void {
    if (entry.ParentNodeId == 0 or entry.NodeId == 0) return PlanningError.InvalidCatalog;
    const is_origin = entry.Kind == .Stack and entry.ParentNodeId == afs.constants.nodes.ORIGIN and entry.NodeId == afs.constants.nodes.ORIGIN_STACK;
    try validateIdentity(entry.Identity, is_origin);
    if (entry.Kind == .Stack) {
        if (entry.LogicalSize != 0) return PlanningError.InvalidCatalog;
    } else {
        _ = try tool.image.geometry.payloadCells(entry.LogicalSize);
    }
}

pub fn keyLength(identity: []const u8) PlanningError!u16 {
    try validateIdentity(identity, true);
    const size = afs.write.stack.indexKeySize(identity.len) catch return PlanningError.InvalidIdentity;
    return std.math.cast(u16, size) orelse return PlanningError.Overflow;
}

pub fn recordLength(entry: Entry, is_index: bool) PlanningError!usize {
    const payload_bytes: usize = if (is_index)
        @sizeOf(u32)
    else switch (entry.Kind) {
        .Stack => @sizeOf(afs.types.catalog.StackRecord),
        .Unit => @sizeOf(afs.types.catalog.UnitRecord),
    };
    return @as(usize, try keyLength(entry.Identity)) + payload_bytes;
}

pub fn recordFits(next_record_offset: usize, record_count: usize, record_length: usize) PlanningError!bool {
    const node_size = afs.constants.sizes.DEFAULT_CELL_SIZE;
    const descriptor_size = constants.NODE_DESCRIPTOR_BYTES;
    if (record_length == 0 or record_length > node_size - descriptor_size - @sizeOf(u16)) return PlanningError.RecordTooLarge;
    if (record_count > std.math.maxInt(u16)) return PlanningError.Overflow;
    if (next_record_offset < descriptor_size or next_record_offset > node_size) return PlanningError.InvalidNode;
    const offset_bytes = (record_count + 1) * @sizeOf(u16);
    if (offset_bytes > node_size - descriptor_size) return false;
    const record_limit = node_size - offset_bytes;
    return record_length <= record_limit and next_record_offset <= record_limit - record_length;
}

fn lessEntry(entries: []const Entry, left: usize, right: usize) bool {
    return compareEntries(entries[left], entries[right]) < 0;
}

fn compareEntries(left: Entry, right: Entry) i32 {
    const right_key = afs.write.stack.createIndexKey(right.ParentNodeId, right.Identity) catch unreachable;
    var identity: [constants.MAXIMUM_IDENTITY_BYTES]u16 = undefined;
    for (left.Identity, 0..) |character, index| identity[index] = character;
    return afs.btree.search.compareKeys(left.ParentNodeId, identity[0..left.Identity.len], &right_key);
}

fn buildLeaves(allocator: std.mem.Allocator, entries: []const Entry, sorted: []const usize, nodes: *std.ArrayList(NodePlan)) !Level {
    const start = nodes.items.len;
    var records: std.ArrayList(RecordPlan) = .empty;
    defer records.deinit(allocator);
    var next_offset = constants.NODE_DESCRIPTOR_BYTES;
    for (sorted) |entry_index| {
        const length = try recordLength(entries[entry_index], false);
        if (!try recordFits(next_offset, records.items.len, length)) {
            try appendNode(allocator, nodes, &records, 1);
            next_offset = constants.NODE_DESCRIPTOR_BYTES;
        }
        try records.append(allocator, .{ .EntryIndex = entry_index, .Length = length });
        next_offset += length;
    }
    try appendNode(allocator, nodes, &records, 1);
    const level = Level{ .Start = start, .Count = nodes.items.len - start, .Height = 1 };
    linkLevel(nodes.items, level);
    return level;
}

fn buildParents(allocator: std.mem.Allocator, entries: []const Entry, nodes: *std.ArrayList(NodePlan), children: Level) !Level {
    if (children.Height == std.math.maxInt(u8)) return PlanningError.Overflow;
    const height = children.Height + 1;
    const start = nodes.items.len;
    var records: std.ArrayList(RecordPlan) = .empty;
    defer records.deinit(allocator);
    var next_offset = constants.NODE_DESCRIPTOR_BYTES;
    for (0..children.Count) |offset| {
        const child_number = children.Start + offset;
        const child = nodes.items[child_number];
        const maximum_entry = child.Records[child.Records.len - 1].EntryIndex;
        const length = try recordLength(entries[maximum_entry], true);
        if (!try recordFits(next_offset, records.items.len, length)) {
            try appendNode(allocator, nodes, &records, height);
            next_offset = constants.NODE_DESCRIPTOR_BYTES;
        }
        try records.append(allocator, .{ .EntryIndex = maximum_entry, .ChildNode = @intCast(child_number), .Length = length });
        next_offset += length;
    }
    try appendNode(allocator, nodes, &records, height);
    const level = Level{ .Start = start, .Count = nodes.items.len - start, .Height = height };
    try rebalanceTail(allocator, nodes.items, level);
    linkLevel(nodes.items, level);
    return level;
}

fn appendNode(allocator: std.mem.Allocator, nodes: *std.ArrayList(NodePlan), records: *std.ArrayList(RecordPlan), height: u8) !void {
    if (records.items.len == 0) return PlanningError.InvalidNode;
    if (nodes.items.len >= std.math.maxInt(u32) or records.items.len > std.math.maxInt(u16)) return PlanningError.Overflow;
    const owned = try records.toOwnedSlice(allocator);
    errdefer allocator.free(owned);
    try nodes.append(allocator, .{ .Number = @intCast(nodes.items.len), .Height = height, .Records = owned });
}

fn rebalanceTail(allocator: std.mem.Allocator, nodes: []NodePlan, level: Level) !void {
    if (level.Count <= 1) return;
    const last_index = level.Start + level.Count - 1;
    const previous = nodes[last_index - 1].Records;
    const last = nodes[last_index].Records;
    if (last.len != 1) return;
    if (previous.len <= 2) return PlanningError.InvalidNode;
    const moved = previous[previous.len - 1];
    if (!try recordFits(constants.NODE_DESCRIPTOR_BYTES + moved.Length, 1, last[0].Length)) return PlanningError.InvalidNode;
    const shortened = try allocator.dupe(RecordPlan, previous[0 .. previous.len - 1]);
    errdefer allocator.free(shortened);
    const expanded = try allocator.alloc(RecordPlan, 2);
    expanded[0] = moved;
    expanded[1] = last[0];
    allocator.free(previous);
    allocator.free(last);
    nodes[last_index - 1].Records = shortened;
    nodes[last_index].Records = expanded;
}

fn linkLevel(nodes: []NodePlan, level: Level) void {
    for (0..level.Count) |offset| {
        const number = level.Start + offset;
        nodes[number].BackwardLink = if (offset == 0) 0 else @intCast(number - 1);
        nodes[number].ForwardLink = if (offset + 1 == level.Count) 0 else @intCast(number + 1);
    }
}
