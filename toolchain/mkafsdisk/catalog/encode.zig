//! Little Endian AFS Planned Catalog Node Encoding

const std = @import("std");

const afs = @import("shared").afs;
const tool = @import("mkafsdisk");

const Entry = tool.types.catalog.Entry;
const NodeDescriptor = afs.types.btree.records.NodeDescriptor;
const PlanningError = tool.errors.planning.PlanningError;
const SpanDescriptor = afs.types.volume.SpanDescriptor;
const TreePlan = tool.types.tree.TreePlan;

const constants = tool.constants.catalog;

pub fn encode(
    plan: *const TreePlan,
    node_number: u32,
    entries: []const Entry,
    spans: []const SpanDescriptor,
    destination: *[afs.constants.sizes.DEFAULT_CELL_SIZE]u8,
) PlanningError!void {
    if (node_number >= plan.Nodes.len or plan.Header.TotalNodes != plan.Nodes.len or
        plan.Header.NodeSize != destination.len or plan.Header.Depth == 0 or plan.Header.Depth > std.math.maxInt(u8))
    {
        return PlanningError.InvalidNode;
    }
    if (spans.len != entries.len) return PlanningError.InvalidSpan;
    const node = plan.Nodes[node_number];
    if (node.Number != node_number) return PlanningError.InvalidNode;
    @memset(destination, 0);
    if (node_number == afs.constants.btree.records.HEADER_NODE_NUMBER) {
        if (node.Height != 0 or node.Records.len != 0) return PlanningError.InvalidNode;
        encodeHeader(plan, destination);
        return;
    }
    if (node.Height == 0 or node.Height > plan.Header.Depth or node.Records.len == 0) return PlanningError.InvalidNode;
    const record_count = std.math.cast(u16, node.Records.len) orelse return PlanningError.Overflow;
    const descriptor = NodeDescriptor{
        .ForwardLink = node.ForwardLink,
        .BackwardLink = node.BackwardLink,
        .NodeType = if (node.Height == 1) afs.constants.btree.records.NODE_TYPE_LEAF else afs.constants.btree.records.NODE_TYPE_INDEX,
        .Height = node.Height,
        .RecordCount = record_count,
    };
    encodeValue(NodeDescriptor, descriptor, destination[0..constants.NODE_DESCRIPTOR_BYTES]);
    var next_offset = constants.NODE_DESCRIPTOR_BYTES;
    for (node.Records, 0..) |record, record_index| {
        if (record.EntryIndex >= entries.len) return PlanningError.InvalidCatalog;
        const entry = entries[record.EntryIndex];
        try tool.catalog.pack.validateEntry(entry);
        const is_index = node.Height > 1;
        const expected_length = try tool.catalog.pack.recordLength(entry, is_index);
        if (record.Length != expected_length or !try tool.catalog.pack.recordFits(next_offset, record_index, record.Length)) {
            return PlanningError.InvalidNode;
        }
        const key_bytes = try tool.catalog.pack.keyLength(entry.Identity);
        encodeKey(entry, destination[next_offset..][0..key_bytes]);
        const payload = destination[next_offset + key_bytes ..][0 .. record.Length - key_bytes];
        if (is_index) {
            if (record.ChildNode == 0 or record.ChildNode >= plan.Nodes.len) return PlanningError.InvalidNode;
            const child = plan.Nodes[record.ChildNode];
            if (@as(u16, child.Height) + 1 != node.Height or child.Records.len == 0 or
                child.Records[child.Records.len - 1].EntryIndex != record.EntryIndex)
            {
                return PlanningError.InvalidNode;
            }
            std.mem.writeInt(u32, payload[0..@sizeOf(u32)], record.ChildNode, .little);
        } else {
            if (record.ChildNode != 0) return PlanningError.InvalidNode;
            try encodeCatalogRecord(entry, spans[record.EntryIndex], payload);
        }
        encodeOffset(destination, record_index, next_offset);
        next_offset += record.Length;
    }
}

fn encodeHeader(plan: *const TreePlan, destination: []u8) void {
    const descriptor = NodeDescriptor{
        .NodeType = afs.constants.btree.records.NODE_TYPE_HEADER,
        .Height = 0,
        .RecordCount = constants.HEADER_RECORD_COUNT,
    };
    encodeValue(NodeDescriptor, descriptor, destination[0..constants.NODE_DESCRIPTOR_BYTES]);
    encodeValue(afs.types.btree.records.HeaderRecord, plan.Header, destination[constants.NODE_DESCRIPTOR_BYTES..][0..constants.HEADER_RECORD_BYTES]);
    encodeOffset(destination, 0, constants.NODE_DESCRIPTOR_BYTES);
}

fn encodeKey(entry: Entry, destination: []u8) void {
    std.mem.writeInt(u16, destination[0..@sizeOf(u16)], @intCast(destination.len), .little);
    std.mem.writeInt(u32, destination[constants.KEY_PARENT_OFFSET..][0..@sizeOf(u32)], entry.ParentNodeId, .little);
    for (entry.Identity, 0..) |character, index| {
        const offset = afs.constants.btree.records.INDEX_KEY_HEADER_SIZE + index * @sizeOf(u16);
        std.mem.writeInt(u16, destination[offset..][0..@sizeOf(u16)], character, .little);
    }
}

fn encodeCatalogRecord(entry: Entry, span: SpanDescriptor, destination: []u8) PlanningError!void {
    if (entry.Kind == .Stack) {
        if (!span.isEmpty() or span.StartCell != 0) return PlanningError.InvalidSpan;
        const record = afs.write.stack.createStackRecord(entry.NodeId, entry.Timestamp, constants.STACK_MODE);
        encodeValue(afs.types.catalog.StackRecord, record, destination);
        return;
    }
    const cells = try tool.image.geometry.payloadCells(entry.LogicalSize);
    if (span.CellCount != cells or (cells == 0 and span.StartCell != 0)) return PlanningError.InvalidSpan;
    _ = std.math.add(u64, span.StartCell, span.CellCount) catch return PlanningError.Overflow;
    const channel = afs.write.unit.createChannelInfo(entry.LogicalSize, span.StartCell, span.CellCount, afs.constants.sizes.DEFAULT_CELL_SIZE) catch |failure|
        return if (failure == error.Overflow) PlanningError.Overflow else PlanningError.InvalidSpan;
    const record = afs.write.stack.createUnitRecord(entry.NodeId, entry.Timestamp, constants.UNIT_MODE, channel);
    encodeValue(afs.types.catalog.UnitRecord, record, destination);
}

fn encodeOffset(destination: []u8, record_index: usize, record_offset: usize) void {
    const offset = destination.len - (record_index + 1) * @sizeOf(u16);
    std.mem.writeInt(u16, destination[offset..][0..@sizeOf(u16)], @intCast(record_offset), .little);
}

pub fn encodeValue(comptime Value: type, value: Value, destination: []u8) void {
    switch (@typeInfo(Value)) {
        .int => std.mem.writeInt(Value, destination[0..@sizeOf(Value)], value, .little),
        .array => |array| for (value, 0..) |element, index| {
            const offset = index * @sizeOf(array.child);
            encodeValue(array.child, element, destination[offset..][0..@sizeOf(array.child)]);
        },
        .@"struct" => |structure| inline for (structure.fields) |field| {
            const offset = @offsetOf(Value, field.name);
            encodeValue(field.type, @field(value, field.name), destination[offset..][0..@sizeOf(field.type)]);
        },
        .@"union" => {
            if (comptime Value == afs.types.catalog.SpecialPermissions) {
                encodeValue(u32, value.InodeNumber, destination);
            } else if (comptime Value == afs.types.catalog.SpecialInfo) {
                encodeValue(@TypeOf(value.Raw), value.Raw, destination);
            } else {
                @compileError(tool.strings.catalog.UNSUPPORTED_WIRE_TYPE);
            }
        },
        else => @compileError(tool.strings.catalog.UNSUPPORTED_WIRE_TYPE),
    }
}

comptime {
    if (@sizeOf(NodeDescriptor) != constants.NODE_DESCRIPTOR_BYTES or
        @sizeOf(afs.types.btree.records.HeaderRecord) != constants.HEADER_RECORD_BYTES or
        @sizeOf(afs.types.catalog.StackRecord) != constants.STACK_RECORD_BYTES or
        @sizeOf(afs.types.catalog.UnitRecord) != constants.UNIT_RECORD_BYTES or
        @offsetOf(afs.types.btree.records.IndexKey, tool.strings.catalog.KEY_PARENT_FIELD) != constants.KEY_PARENT_OFFSET or
        @offsetOf(afs.types.btree.records.IndexKey, tool.strings.catalog.KEY_IDENTITY_FIELD) != afs.constants.btree.records.INDEX_KEY_HEADER_SIZE)
    {
        @compileError(tool.strings.catalog.INVALID_WIRE_LAYOUT);
    }
}
