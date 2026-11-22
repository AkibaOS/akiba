//! Hikari AFS Reader

const afs = @import("shared").afs;
const disk = @import("hikari").disk;
const efi = @import("hikari").efi;
const errors = @import("hikari").fs.errors;
const locations = @import("shared").location;
const text = @import("common").text;
const types = @import("hikari").fs.types;

const BTree = types.afs.btree.BTree;
const BTreeHeaderRecord = afs.types.btree.records.HeaderRecord;
const BTreeNodeDescriptor = afs.types.btree.records.NodeDescriptor;
const MediaSnapshot = disk.types.media.MediaSnapshot;
const ReadError = errors.afs.ReadError;
const SpanDescriptor = afs.types.volume.SpanDescriptor;
const UnitRecord = afs.types.catalog.UnitRecord;
const VolumeHeader = afs.types.volume.VolumeHeader;

const constants = afs.constants;

pub const Reader = struct {
    BootServices: *efi.types.services.boot.BootServices,
    Media: MediaSnapshot = undefined,
    PartitionStartLBA: u64 = 0,
    PartitionEndLBA: u64 = 0,
    VolumeHeader: VolumeHeader = undefined,
    CellSize: u32 = 0,
    Index: BTree = .{},
    HasSpanOverflow: bool = false,
    CellAllocation: efi.types.buffer.claims.AlignedBuffer = .{},
    NodeAllocation: efi.types.buffer.claims.PoolClaim = .{},

    pub fn initialize(
        self: *Reader,
        media: MediaSnapshot,
        partition_start_lba: u64,
        partition_end_lba: u64,
    ) ReadError!void {
        if (!self.CellAllocation.Pool.isEmpty() or !self.NodeAllocation.isEmpty()) return ReadError.AllocationFailed;
        if (!media.isCurrent()) return ReadError.ReadFailed;
        const block_size = media.BlockSize;
        if (block_size < @sizeOf(VolumeHeader) or block_size > constants.sizes.MAXIMUM_CELL_SIZE or
            (block_size & (block_size - 1)) != 0 or partition_start_lba == 0 or
            partition_end_lba < partition_start_lba or partition_end_lba > media.LastBlock)
        {
            return ReadError.InvalidVolumeHeader;
        }
        if (!efi.buffer.allocate(self.BootServices, block_size, media.IOAlign, &self.CellAllocation)) return ReadError.AllocationFailed;
        if (!media.read(partition_start_lba, self.CellAllocation.Data[0..block_size])) return ReadError.ReadFailed;

        const header = @as(*const VolumeHeader, @ptrCast(@alignCast(self.CellAllocation.Data))).*;
        if (!header.isValid() or header.CellSize < block_size or (header.CellSize & (header.CellSize - 1)) != 0 or
            header.CellSize % block_size != 0 or header.TotalCells == 0 or header.FreeCells > header.TotalCells or
            header.CompressionType != constants.flags.COMPRESSION_NONE or header.EncryptionType != constants.flags.ENCRYPTION_NONE)
        {
            return ReadError.InvalidVolumeHeader;
        }
        const partition_cells = (partition_end_lba - partition_start_lba + 1) / (header.CellSize / block_size);
        if (header.TotalCells > partition_cells or !afs.read.bounds.spanFits(header.IndexSpan, header.TotalCells)) {
            return ReadError.InvalidVolumeHeader;
        }
        if (header.CellSize != block_size) {
            if (!efi.buffer.release(self.BootServices, &self.CellAllocation)) return ReadError.ReleaseFailed;
            if (!efi.buffer.allocate(self.BootServices, header.CellSize, media.IOAlign, &self.CellAllocation)) return ReadError.AllocationFailed;
        }
        const cell_buffer = self.CellAllocation.Data[0..self.CellAllocation.Size];
        const index_header = try readBtreeHeader(media, partition_start_lba, partition_end_lba, cell_buffer, header.IndexSpan);
        const index = BTree.initialize(
            media,
            self.BootServices,
            partition_start_lba,
            partition_end_lba,
            cell_buffer,
            header.IndexSpan,
            &index_header,
            &self.NodeAllocation,
        ) catch return ReadError.BTreeError;
        if (!media.isCurrent()) return ReadError.ReadFailed;

        self.Media = media;
        self.PartitionStartLBA = partition_start_lba;
        self.PartitionEndLBA = partition_end_lba;
        self.VolumeHeader = header;
        self.Index = index;
        self.HasSpanOverflow = !header.SpanOverflowSpan.isEmpty();
        self.CellSize = header.CellSize;
    }

    pub fn deinitialize(self: *Reader) bool {
        self.Index.close();
        self.CellSize = 0;
        const nodes_released = efi.buffer.releasePool(self.BootServices, &self.NodeAllocation);
        const cell_released = efi.buffer.release(self.BootServices, &self.CellAllocation);
        return nodes_released and cell_released;
    }

    pub fn openLocation(self: *Reader, path: []const u8) ReadError!UnitRecord {
        if (self.CellSize == 0) return ReadError.ReadFailed;
        var current_node_id: u32 = constants.nodes.ORIGIN_STACK;
        var iterator = locations.types.iterator.LocationIterator.init(path);
        while (iterator.next()) |component| {
            var identity_utf16: [@as(afs.types.btree.records.IndexKey, undefined).Identity.len]u16 = undefined;
            if (component.len == 0 or component.len > identity_utf16.len) return ReadError.InvalidIdentity;
            const identity_length = text.ascii.widenToUtf16(&identity_utf16, component);
            const identity = identity_utf16[0..identity_length];
            const stack_record = self.Index.searchIndexForStack(current_node_id, identity) catch return ReadError.BTreeError;
            if (stack_record) |found_stack| {
                current_node_id = found_stack.NodeId;
                continue;
            }
            const unit_record = self.Index.searchIndex(current_node_id, identity) catch return ReadError.BTreeError;
            if (unit_record) |found_unit| {
                if (iterator.next() != null) return ReadError.NotAStack;
                return found_unit.*;
            }
            return ReadError.NotFound;
        }
        return ReadError.NotFound;
    }

    pub fn readCell(self: *Reader, cell_number: u64) ReadError!void {
        if (self.CellSize == 0) return ReadError.ReadFailed;
        if (cell_number >= self.VolumeHeader.TotalCells) return ReadError.InvalidSpan;
        const cell_lba = afs.read.bounds.cellLBA(
            self.PartitionStartLBA,
            self.PartitionEndLBA,
            self.Media.BlockSize,
            self.CellSize,
            cell_number,
            self.CellSize,
        ) orelse return ReadError.InvalidSpan;
        if (!self.Media.read(cell_lba, self.CellAllocation.Data[0..self.CellSize])) return ReadError.ReadFailed;
    }

    pub fn readUnit(self: *Reader, unit: *const UnitRecord, buffer: [*]u8, max_size: u64) ReadError!u64 {
        if (self.CellSize == 0) return ReadError.ReadFailed;
        const channel = &unit.DataChannel;
        const unit_size = channel.LogicalSize;
        if (unit_size > max_size) return ReadError.UnitTooLarge;
        if (channel.TotalCells > self.VolumeHeader.TotalCells or unit_size > channel.PhysicalSize or
            channel.PhysicalSize > @as(u64, channel.TotalCells) * self.CellSize)
        {
            return ReadError.InvalidSpan;
        }
        var bytes_read: u64 = 0;
        var cells_used: u64 = 0;
        var span_index: usize = 0;
        while (bytes_read < unit_size and span_index < constants.sizes.SPAN_INLINE_COUNT) : (span_index += 1) {
            const span = channel.getSpan(span_index) orelse break;
            if (!afs.read.bounds.spanFits(span.*, self.VolumeHeader.TotalCells) or
                span.CellCount > channel.TotalCells - cells_used)
            {
                return ReadError.InvalidSpan;
            }
            const bytes_to_read = @min(unit_size - bytes_read, span.byteSize(self.CellSize));
            try self.readSpanData(span, buffer + bytes_read, bytes_to_read);
            bytes_read += bytes_to_read;
            cells_used += span.CellCount;
        }
        if (bytes_read != unit_size) {
            return if (self.HasSpanOverflow) ReadError.UnsupportedSpans else ReadError.InvalidSpan;
        }
        return bytes_read;
    }

    fn readSpanData(self: *Reader, span: *const SpanDescriptor, buffer: [*]u8, size: u64) ReadError!void {
        var bytes_read: u64 = 0;
        var current_cell = span.StartCell;
        while (bytes_read < size) : (current_cell += 1) {
            try self.readCell(current_cell);
            const bytes_to_copy = @min(size - bytes_read, self.CellSize);
            @memcpy(buffer[bytes_read..][0..bytes_to_copy], self.CellAllocation.Data[0..bytes_to_copy]);
            bytes_read += bytes_to_copy;
        }
    }

    pub fn readUnitToAllocated(self: *Reader, unit: *const UnitRecord, max_size: u64, owner: *efi.types.buffer.claims.PoolClaim) ReadError![]u8 {
        if (self.CellSize == 0) return ReadError.ReadFailed;
        const unit_size = unit.DataChannel.LogicalSize;
        if (unit_size == 0 or unit_size > max_size) return ReadError.UnitTooLarge;
        const volume_size = @mulWithOverflow(@as(u64, self.VolumeHeader.TotalCells), @as(u64, self.CellSize));
        if (volume_size[1] != 0 or unit_size > volume_size[0]) return ReadError.UnitTooLarge;
        if (!efi.buffer.allocatePool(self.BootServices, @intCast(unit_size), owner)) return ReadError.AllocationFailed;
        const buffer = owner.Allocation.?;
        const bytes_read = try self.readUnit(unit, buffer, max_size);
        return buffer[0..@intCast(bytes_read)];
    }

    fn readBtreeHeader(
        media: MediaSnapshot,
        partition_start_lba: u64,
        partition_end_lba: u64,
        cell_buffer: []align(8) u8,
        span: SpanDescriptor,
    ) ReadError!BTreeHeaderRecord {
        const cell_size: u32 = @intCast(cell_buffer.len);
        if (cell_size < @sizeOf(BTreeNodeDescriptor) + @sizeOf(BTreeHeaderRecord)) return ReadError.InvalidVolumeHeader;
        const cell_lba = afs.read.bounds.cellLBA(partition_start_lba, partition_end_lba, media.BlockSize, cell_size, span.StartCell, cell_size) orelse return ReadError.InvalidSpan;
        if (!media.read(cell_lba, cell_buffer)) return ReadError.ReadFailed;
        const descriptor: *const BTreeNodeDescriptor = @ptrCast(cell_buffer.ptr);
        if (!descriptor.isHeader() or descriptor.RecordCount == 0) return ReadError.InvalidVolumeHeader;
        return @as(*const BTreeHeaderRecord, @ptrCast(@alignCast(cell_buffer.ptr + @sizeOf(BTreeNodeDescriptor)))).*;
    }
};
