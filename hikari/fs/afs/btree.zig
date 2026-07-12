//! Hikari AFS B-Tree

const afs = @import("shared").afs;
const efi = @import("../../efi/efi.zig");
const errors = @import("../errors/errors.zig");

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
    BlockIO: *efi.protocols.block.BlockIoProtocol,
    BootServices: *efi.services.boot.BootServices,
    PartitionStartLBA: u64,
    CellSize: u32,
    BaseSpan: SpanDescriptor,
    NodeSize: u32,
    RootNode: u32,
    FirstLeaf: u32,
    LastLeaf: u32,
    Depth: u16,
    NodeBuffer: [*]u8,

    pub fn initialize(
        block_io: *efi.protocols.block.BlockIoProtocol,
        boot_services: *efi.services.boot.BootServices,
        partition_start_lba: u64,
        cell_size: u32,
        base_span: SpanDescriptor,
        header: *const BTreeHeaderRecord,
    ) BTreeError!BTree {
        var node_buffer: [*]align(8) u8 = undefined;
        const allocation_status = boot_services.AllocatePool(
            .LoaderData,
            header.NodeSize,
            &node_buffer,
        );
        if (efi.types.base.isError(allocation_status)) {
            return BTreeError.AllocationFailed;
        }

        return BTree{
            .BlockIO = block_io,
            .BootServices = boot_services,
            .PartitionStartLBA = partition_start_lba,
            .CellSize = cell_size,
            .BaseSpan = base_span,
            .NodeSize = header.NodeSize,
            .RootNode = header.RootNode,
            .FirstLeaf = header.FirstLeafNode,
            .LastLeaf = header.LastLeafNode,
            .Depth = header.Depth,
            .NodeBuffer = node_buffer,
        };
    }

    pub fn readNode(self: *BTree, node_number: u32) BTreeError!*BTreeNodeDescriptor {
        const cell_offset = node.getNodeCell(node_number, self.CellSize, self.NodeSize);
        const node_offset_in_cell = node.getNodeOffsetInCell(node_number, self.CellSize, self.NodeSize);

        const cell_lba = self.PartitionStartLBA +
            ((self.BaseSpan.StartCell + cell_offset) * self.CellSize / self.BlockIO.Media.BlockSize);

        var cell_buffer: [*]align(8) u8 = undefined;
        const allocation_status = self.BootServices.AllocatePool(
            .LoaderData,
            self.CellSize,
            &cell_buffer,
        );
        if (efi.types.base.isError(allocation_status)) {
            return BTreeError.AllocationFailed;
        }

        const read_status = self.BlockIO.ReadBlocks(
            self.BlockIO,
            self.BlockIO.Media.MediaId,
            cell_lba,
            self.CellSize,
            cell_buffer,
        );
        if (efi.types.base.isError(read_status)) {
            return BTreeError.ReadFailed;
        }

        const node_pointer = cell_buffer + node_offset_in_cell;
        var index: u32 = 0;
        while (index < self.NodeSize) : (index += 1) {
            self.NodeBuffer[index] = node_pointer[index];
        }

        _ = self.BootServices.FreePool(cell_buffer);

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
