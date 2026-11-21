//! Enumerate Children Of A Named AFS Stack

const afs = @import("shared").afs;

const Catalog = afs.types.reader.Catalog;
const Entry = afs.types.read.list.Entry;
const IndexKey = afs.types.btree.records.IndexKey;
const Kind = afs.types.read.list.Kind;
const NodeDescriptor = afs.types.btree.records.NodeDescriptor;
const ReadError = afs.errors.read.transfers.ReadError;

pub fn child(catalog: *const Catalog, parents: []const []const u8, ordinal: u64, scratch: []u8) ReadError!?Entry {
    if (scratch.len < catalog.Reader.CellSize) return ReadError.BufferTooSmall;
    const stack = (try afs.read.catalog.stack(catalog, parents, scratch)) orelse return ReadError.MissingStack;
    var pending = ordinal;
    var previous: u32 = 0;
    var node = catalog.Index.FirstLeafNode;
    var leaves: u32 = 0;
    while (node != 0) : (leaves += 1) {
        if (leaves >= catalog.Index.TotalNodes) return ReadError.InvalidCatalog;
        const bytes = try leaf(catalog, node, scratch);
        const descriptor: *align(1) const NodeDescriptor = @ptrCast(bytes.ptr);
        if (descriptor.BackwardLink != previous or (node == catalog.Index.LastLeafNode) != (descriptor.ForwardLink == 0))
            return ReadError.InvalidCatalog;
        if (try scan(bytes, descriptor.RecordCount, stack, &pending)) |found| return found;
        previous = node;
        node = descriptor.ForwardLink;
    }
    return null;
}

fn leaf(catalog: *const Catalog, index: u32, scratch: []u8) ReadError![]const u8 {
    if (index >= catalog.Index.TotalNodes) return ReadError.InvalidCatalog;
    const per_cell = catalog.Reader.CellSize / catalog.Index.NodeSize;
    const cell = catalog.Span.StartCell + index / per_cell;
    catalog.Reader.readCell(cell, scratch) catch return ReadError.ReadFailed;
    const offset = (index % per_cell) * catalog.Index.NodeSize;
    const bytes = scratch[offset..][0..catalog.Index.NodeSize];
    if (!afs.btree.validate.catalogNode(bytes)) return ReadError.InvalidCatalog;
    const descriptor = @as(*align(1) const NodeDescriptor, @ptrCast(bytes.ptr)).*;
    if (!descriptor.isLeaf() or descriptor.Height != 1) return ReadError.InvalidCatalog;
    return bytes;
}

fn scan(bytes: []const u8, count: u16, stack: u32, pending: *u64) ReadError!?Entry {
    for (0..count) |index| {
        const pointer = afs.btree.node.getRecordPointerConst(bytes.ptr, @intCast(bytes.len), @intCast(index));
        const key: *align(1) const IndexKey = @ptrCast(pointer);
        if (key.ParentNodeId != stack) continue;
        const record_type: *align(1) const u16 = @ptrCast(pointer + key.KeyLength);
        const kind: Kind = switch (record_type.*) {
            afs.constants.records.INDEX_STACK => .Stack,
            afs.constants.records.INDEX_UNIT => .Unit,
            else => continue,
        };
        const length = key.getIdentityLength();
        if (length == 0) return ReadError.InvalidCatalog;
        if (pending.* != 0) {
            pending.* -= 1;
            continue;
        }
        var result: Entry = .{ .Kind = kind, .Length = @intCast(length) };
        @memcpy(result.Identity[0..length], key.Identity[0..length]);
        return result;
    }
    return null;
}
