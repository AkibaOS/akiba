//! Hikari AFS B-Tree

const std = @import("std");

const afs = @import("shared").afs;
const disk = @import("hikari").disk;
const efi = @import("hikari").efi;
const errors = @import("hikari").fs.errors;

const BTreeError = errors.afs.BTreeError;
const BTreeNodeDescriptor = afs.types.btree.records.NodeDescriptor;
const BTreeHeaderRecord = afs.types.btree.records.HeaderRecord;
const MediaSnapshot = disk.types.media.MediaSnapshot;
const StackRecord = afs.types.catalog.StackRecord;
const UnitRecord = afs.types.catalog.UnitRecord;
const ThreadRecord = afs.types.catalog.ThreadRecord;
const SpanDescriptor = afs.types.volume.SpanDescriptor;
const node = afs.btree.node;
const search = afs.btree.search;

pub const BTree = struct {
    Media: MediaSnapshot = undefined,
    PartitionStartLBA: u64 = 0,
    PartitionEndLBA: u64 = 0,
    CellSize: u32 = 0,
    BaseSpan: SpanDescriptor = .{},
    NodeSize: u32 = 0,
    RootNode: u32 = 0,
    FirstLeaf: u32 = 0,
    LastLeaf: u32 = 0,
    Depth: u16 = 0,
    TotalNodes: u32 = 0,
    CellBuffer: []align(8) u8 = undefined,
    NodeBuffer: [*]align(8) u8 = undefined,

    pub fn initialize(
        media: MediaSnapshot,
        boot_services: *efi.types.services.boot.BootServices,
        partition_start_lba: u64,
        partition_end_lba: u64,
        cell_buffer: []align(8) u8,
        base_span: SpanDescriptor,
        header: *const BTreeHeaderRecord,
        node_owner: *efi.types.buffer.claims.PoolClaim,
    ) BTreeError!BTree {
        const cell_size = std.math.cast(u32, cell_buffer.len) orelse return BTreeError.InvalidHeader;
        const block_size = media.BlockSize;
        if (afs.read.bounds.cellLBA(partition_start_lba, partition_end_lba, block_size, cell_size, base_span.StartCell, cell_size) == null or
            header.NodeSize < @sizeOf(BTreeNodeDescriptor) + @sizeOf(u16) or header.NodeSize > cell_size or
            cell_size % header.NodeSize != 0 or header.TotalNodes == 0 or header.FreeNodes > header.TotalNodes or
            header.Depth > std.math.maxInt(u8))
        {
            return BTreeError.InvalidHeader;
        }
        const total_cells = (partition_end_lba - partition_start_lba + 1) / (cell_size / block_size);
        if (!afs.read.bounds.spanFits(base_span, total_cells) or
            @as(u64, header.TotalNodes) > base_span.CellCount * (cell_size / header.NodeSize) or
            (header.Depth != 0 and (header.RootNode == 0 or header.RootNode >= header.TotalNodes or
                header.FirstLeafNode == 0 or header.FirstLeafNode >= header.TotalNodes or
                header.LastLeafNode == 0 or header.LastLeafNode >= header.TotalNodes)))
        {
            return BTreeError.InvalidHeader;
        }
        if (!efi.buffer.allocatePool(boot_services, header.NodeSize, node_owner)) return BTreeError.AllocationFailed;

        return BTree{
            .Media = media,
            .PartitionStartLBA = partition_start_lba,
            .PartitionEndLBA = partition_end_lba,
            .CellSize = cell_size,
            .BaseSpan = base_span,
            .NodeSize = header.NodeSize,
            .RootNode = header.RootNode,
            .FirstLeaf = header.FirstLeafNode,
            .LastLeaf = header.LastLeafNode,
            .Depth = header.Depth,
            .TotalNodes = header.TotalNodes,
            .CellBuffer = cell_buffer,
            .NodeBuffer = node_owner.Allocation.?,
        };
    }

    pub fn close(self: *BTree) void {
        self.* = .{};
    }

    pub fn readNode(self: *BTree, node_number: u32) BTreeError!*BTreeNodeDescriptor {
        if (node_number >= self.TotalNodes) return BTreeError.InvalidNode;
        const cell_offset = node.getNodeCell(node_number, self.CellSize, self.NodeSize);
        const node_offset_in_cell = node.getNodeOffsetInCell(node_number, self.CellSize, self.NodeSize);

        if (cell_offset >= self.BaseSpan.CellCount) return BTreeError.InvalidNode;
        const cell_lba = afs.read.bounds.cellLBA(
            self.PartitionStartLBA,
            self.PartitionEndLBA,
            self.Media.BlockSize,
            self.CellSize,
            self.BaseSpan.StartCell + cell_offset,
            self.CellSize,
        ) orelse return BTreeError.InvalidNode;

        if (!self.Media.read(cell_lba, self.CellBuffer)) return BTreeError.ReadFailed;
        @memcpy(self.NodeBuffer[0..self.NodeSize], self.CellBuffer[node_offset_in_cell..][0..self.NodeSize]);

        if (!afs.btree.validate.catalogNode(self.NodeBuffer[0..self.NodeSize])) return BTreeError.InvalidNode;
        return @ptrCast(@alignCast(self.NodeBuffer));
    }

    pub fn searchIndex(
        self: *BTree,
        parent_node_id: u32,
        identity: []const u16,
    ) BTreeError!?*align(1) const UnitRecord {
        if (self.Depth == 0) {
            return BTreeError.TreeEmpty;
        }

        var current_node = self.RootNode;
        var current_depth: u16 = self.Depth;

        while (current_depth > 0) {
            const node_descriptor = try self.readNode(current_node);
            if (node_descriptor.Height != current_depth or node_descriptor.isLeaf() != (current_depth == 1)) {
                return BTreeError.InvalidNode;
            }

            if (node_descriptor.isLeaf()) {
                return search.searchLeafForUnit(
                    self.NodeBuffer,
                    self.NodeSize,
                    node_descriptor.RecordCount,
                    parent_node_id,
                    identity,
                );
            }

            const next_node = search.searchIndexNode(
                self.NodeBuffer,
                self.NodeSize,
                node_descriptor.RecordCount,
                parent_node_id,
                identity,
            );
            if (next_node) |found| {
                current_node = found;
                current_depth -= 1;
            } else {
                return null;
            }
        }

        return null;
    }

    pub fn searchIndexForStack(
        self: *BTree,
        parent_node_id: u32,
        identity: []const u16,
    ) BTreeError!?*align(1) const StackRecord {
        if (self.Depth == 0) {
            return BTreeError.TreeEmpty;
        }

        var current_node = self.RootNode;
        var current_depth: u16 = self.Depth;

        while (current_depth > 0) {
            const node_descriptor = try self.readNode(current_node);
            if (node_descriptor.Height != current_depth or node_descriptor.isLeaf() != (current_depth == 1)) {
                return BTreeError.InvalidNode;
            }

            if (node_descriptor.isLeaf()) {
                return search.searchLeafForStack(
                    self.NodeBuffer,
                    self.NodeSize,
                    node_descriptor.RecordCount,
                    parent_node_id,
                    identity,
                );
            }

            const next_node = search.searchIndexNode(
                self.NodeBuffer,
                self.NodeSize,
                node_descriptor.RecordCount,
                parent_node_id,
                identity,
            );
            if (next_node) |found| {
                current_node = found;
                current_depth -= 1;
            } else {
                return null;
            }
        }

        return null;
    }

    pub fn getThreadRecord(
        self: *BTree,
        node_id: u32,
    ) BTreeError!?*align(1) const ThreadRecord {
        var empty_identity: [0]u16 = undefined;
        return self.searchThread(node_id, &empty_identity);
    }

    fn searchThread(
        self: *BTree,
        node_id: u32,
        identity: []const u16,
    ) BTreeError!?*align(1) const ThreadRecord {
        if (self.Depth == 0) {
            return BTreeError.TreeEmpty;
        }

        var current_node = self.RootNode;
        var current_depth: u16 = self.Depth;

        while (current_depth > 0) {
            const node_descriptor = try self.readNode(current_node);
            if (node_descriptor.Height != current_depth or node_descriptor.isLeaf() != (current_depth == 1)) {
                return BTreeError.InvalidNode;
            }

            if (node_descriptor.isLeaf()) {
                return search.searchLeafForThread(
                    self.NodeBuffer,
                    self.NodeSize,
                    node_descriptor.RecordCount,
                    node_id,
                    identity,
                );
            }

            const next_node = search.searchIndexNode(
                self.NodeBuffer,
                self.NodeSize,
                node_descriptor.RecordCount,
                node_id,
                identity,
            );
            if (next_node) |found| {
                current_node = found;
                current_depth -= 1;
            } else {
                return null;
            }
        }

        return null;
    }
};
