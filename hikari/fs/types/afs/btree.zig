//! Hikari AFS B-Tree

const std = @import("std");

const afs = @import("shared").afs;
const efi = @import("hikari").efi;
const errors = @import("hikari").fs.errors;

const BTreeError = errors.afs.BTreeError;
const BTreeNodeDescriptor = afs.types.btree.NodeDescriptor;
const BTreeHeaderRecord = afs.types.btree.HeaderRecord;
const StackRecord = afs.types.catalog.StackRecord;
const UnitRecord = afs.types.catalog.UnitRecord;
const ThreadRecord = afs.types.catalog.ThreadRecord;
const SpanDescriptor = afs.types.volume.SpanDescriptor;
const node = afs.btree.node;
const search = afs.btree.search;

pub const BTree = struct {
    BlockIO: *efi.types.protocols.block.BlockIoProtocol,
    BootServices: *efi.types.services.boot.BootServices,
    PartitionStartLBA: u64,
    PartitionEndLBA: u64,
    CellSize: u32,
    BaseSpan: SpanDescriptor,
    NodeSize: u32,
    RootNode: u32,
    FirstLeaf: u32,
    LastLeaf: u32,
    Depth: u16,
    TotalNodes: u32,
    NodeBuffer: [*]align(8) u8,

    pub fn initialize(
        block_io: *efi.types.protocols.block.BlockIoProtocol,
        boot_services: *efi.types.services.boot.BootServices,
        partition_start_lba: u64,
        partition_end_lba: u64,
        cell_size: u32,
        base_span: SpanDescriptor,
        header: *const BTreeHeaderRecord,
    ) BTreeError!BTree {
        const block_size = block_io.Media.BlockSize;
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
        var node_buffer: [*]align(8) u8 = undefined;
        const allocation_status = boot_services.AllocatePool(
            .LoaderData,
            header.NodeSize,
            &node_buffer,
        );
        if (efi.status.isError(allocation_status)) {
            return BTreeError.AllocationFailed;
        }

        return BTree{
            .BlockIO = block_io,
            .BootServices = boot_services,
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
            .NodeBuffer = node_buffer,
        };
    }

    pub fn deinitialize(self: *BTree) void {
        if (self.TotalNodes == 0) return;
        _ = self.BootServices.FreePool(self.NodeBuffer);
        self.TotalNodes = 0;
        self.Depth = 0;
    }

    pub fn readNode(self: *BTree, node_number: u32) BTreeError!*BTreeNodeDescriptor {
        if (node_number >= self.TotalNodes) return BTreeError.InvalidNode;
        const cell_offset = node.getNodeCell(node_number, self.CellSize, self.NodeSize);
        const node_offset_in_cell = node.getNodeOffsetInCell(node_number, self.CellSize, self.NodeSize);

        if (cell_offset >= self.BaseSpan.CellCount) return BTreeError.InvalidNode;
        const cell_lba = afs.read.bounds.cellLBA(
            self.PartitionStartLBA,
            self.PartitionEndLBA,
            self.BlockIO.Media.BlockSize,
            self.CellSize,
            self.BaseSpan.StartCell + cell_offset,
            self.CellSize,
        ) orelse return BTreeError.InvalidNode;

        var cell_buffer = efi.buffer.allocate(self.BootServices, self.CellSize, self.BlockIO.Media.IOAlign) orelse return BTreeError.AllocationFailed;
        defer efi.buffer.release(self.BootServices, &cell_buffer);
        const read_status = self.BlockIO.ReadBlocks(
            self.BlockIO,
            self.BlockIO.Media.MediaId,
            cell_lba,
            self.CellSize,
            cell_buffer.Data,
        );
        if (efi.status.isError(read_status)) {
            return BTreeError.ReadFailed;
        }

        const node_pointer = cell_buffer.Data + node_offset_in_cell;
        var index: u32 = 0;
        while (index < self.NodeSize) : (index += 1) {
            self.NodeBuffer[index] = node_pointer[index];
        }

        if (!afs.btree.validate.catalogNode(self.NodeBuffer[0..self.NodeSize])) return BTreeError.InvalidNode;
        return @ptrCast(@alignCast(self.NodeBuffer));
    }

    pub fn getRecordOffset(self: *BTree, record_index: u16) u16 {
        return node.getRecordOffset(self.NodeBuffer, self.NodeSize, record_index);
    }

    pub fn getRecordPointer(self: *BTree, record_index: u16) [*]u8 {
        return node.getRecordPointer(self.NodeBuffer, self.NodeSize, record_index);
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
