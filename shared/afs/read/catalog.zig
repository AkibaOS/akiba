//! Mount And Walk A Bounded AFS Catalog

const std = @import("std");

const afs = @import("shared").afs;
const bounds = afs.read.bounds;
const limits = afs.constants.sizes;
const search = afs.btree.search;
const separators = @import("utils").path.constants.separators;

const BlockReader = afs.types.block.BlockReader;
const Catalog = afs.types.reader.Catalog;
const Header = afs.types.btree.records.HeaderRecord;
const Node = afs.types.btree.records.NodeDescriptor;
const ReadError = afs.errors.read.transfers.ReadError;
const Unit = afs.types.catalog.UnitRecord;
const Volume = afs.types.volume.VolumeHeader;

pub fn mount(reader: BlockReader, scratch: []u8) ReadError!Catalog {
    const size = reader.CellSize;
    if (size < limits.MINIMUM_CELL_SIZE or size > limits.MAXIMUM_CELL_SIZE or !std.math.isPowerOfTwo(size) or
        reader.TotalCells == 0) return error.InvalidVolumeHeader;
    if (scratch.len < size) return error.BufferTooSmall;
    reader.readCell(0, scratch) catch return error.ReadFailed;
    const volume = @as(*align(1) const Volume, @ptrCast(scratch.ptr)).*;
    if (!volume.isValid() or volume.CellSize != size or volume.TotalCells > reader.TotalCells or
        volume.FreeCells > volume.TotalCells or volume.IndexSpan.StartCell == 0 or !bounds.spanFits(volume.IndexSpan, volume.TotalCells) or
        volume.CompressionType != afs.constants.flags.COMPRESSION_NONE or volume.EncryptionType != afs.constants.flags.ENCRYPTION_NONE)
        return error.InvalidVolumeHeader;
    var bounded = reader;
    bounded.TotalCells = volume.TotalCells;
    bounded.readCell(volume.IndexSpan.StartCell, scratch) catch return error.ReadFailed;
    const node = @as(*align(1) const Node, @ptrCast(scratch.ptr)).*;
    if (!node.isHeader() or node.RecordCount == 0) return error.InvalidCatalog;
    const index = @as(*align(1) const Header, @ptrCast(scratch.ptr + @sizeOf(Node))).*;
    if (index.NodeSize < @sizeOf(Node) + @sizeOf(Header) or index.NodeSize > size or size % index.NodeSize != 0 or
        index.Depth == 0 or index.Depth > std.math.maxInt(u8) or index.FreeNodes > index.TotalNodes or
        index.RootNode == 0 or index.RootNode >= index.TotalNodes or index.TotalNodes > volume.IndexSpan.CellCount * (size / index.NodeSize) or
        index.FirstLeafNode == 0 or index.FirstLeafNode >= index.TotalNodes or index.LastLeafNode == 0 or index.LastLeafNode >= index.TotalNodes or
        index.Depth != volume.IndexDepth or index.NodeSize != volume.IndexNodeSize or index.RootNode != volume.IndexRootNode or
        index.TotalNodes != volume.IndexTotalNodes) return error.InvalidCatalog;
    return .{ .Reader = bounded, .Index = index, .Span = volume.IndexSpan };
}

pub fn stack(catalog: *const Catalog, parents: []const []const u8, scratch: []u8) ReadError!?u32 {
    var parent_id = afs.constants.nodes.ORIGIN_STACK;
    var wide: [@as(afs.types.btree.records.IndexKey, undefined).Identity.len]u16 = undefined;
    for (parents) |component| {
        const identity = try widen(component, &wide);
        const leaf = (try findLeaf(catalog, parent_id, identity, scratch)) orelse return null;
        const record = search.searchLeafForStack(leaf.ptr, catalog.Index.NodeSize, descriptor(leaf).RecordCount, parent_id, identity) orelse return null;
        if (record.NodeId < afs.constants.nodes.FIRST_USER or record.NodeId == parent_id) return error.InvalidCatalog;
        parent_id = record.NodeId;
    }
    return parent_id;
}

pub fn open(catalog: *const Catalog, parents: []const []const u8, name: []const u8, scratch: []u8) ReadError!?Unit {
    const parent_id = (try stack(catalog, parents, scratch)) orelse return null;
    var wide: [@as(afs.types.btree.records.IndexKey, undefined).Identity.len]u16 = undefined;
    const identity = try widen(name, &wide);
    const leaf = (try findLeaf(catalog, parent_id, identity, scratch)) orelse return null;
    const unit = search.searchLeafForUnit(leaf.ptr, catalog.Index.NodeSize, descriptor(leaf).RecordCount, parent_id, identity) orelse return null;
    if (unit.NodeId < afs.constants.nodes.FIRST_USER) return error.InvalidCatalog;
    return unit.*;
}

fn findLeaf(catalog: *const Catalog, parent_id: u32, identity: []const u16, scratch: []u8) ReadError!?[]const u8 {
    const per_cell = catalog.Reader.CellSize / catalog.Index.NodeSize;
    var index = catalog.Index.RootNode;
    var depth = catalog.Index.Depth;
    while (depth != 0) : (depth -= 1) {
        if (index == 0 or index >= catalog.Index.TotalNodes) return error.InvalidCatalog;
        const cell = catalog.Span.StartCell + index / per_cell;
        catalog.Reader.readCell(cell, scratch) catch return error.ReadFailed;
        const offset = (index % per_cell) * catalog.Index.NodeSize;
        const bytes = scratch[offset..][0..catalog.Index.NodeSize];
        if (!afs.btree.validate.catalogNode(bytes)) return error.InvalidCatalog;
        const node = descriptor(bytes);
        if (node.Height != depth or node.RecordCount == 0 or node.isLeaf() != (depth == 1)) return error.InvalidCatalog;
        if (node.isLeaf()) return bytes;
        index = search.searchIndexNode(bytes.ptr, catalog.Index.NodeSize, node.RecordCount, parent_id, identity) orelse return error.InvalidCatalog;
    }
    return error.InvalidCatalog;
}

fn descriptor(bytes: []const u8) Node {
    return @as(*align(1) const Node, @ptrCast(bytes.ptr)).*;
}

fn widen(component: []const u8, output: []u16) ReadError![]const u16 {
    if (component.len == 0 or component.len > output.len) return error.InvalidIdentity;
    for (component, 0..) |character, index| {
        switch (character) {
            0, separators.FORWARD_SLASH, separators.BACK_SLASH => return error.InvalidIdentity,
            else => output[index] = character,
        }
    }
    return output[0..component.len];
}
