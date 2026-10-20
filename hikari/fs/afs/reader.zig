//! Hikari AFS Reader

const afs = @import("shared").afs;
const btree = @import("hikari").fs.afs.btree;
const efi = @import("hikari").efi;
const errors = @import("hikari").fs.errors;
const text = @import("utils").text;
const utils = @import("utils");

const ReadError = errors.afs.ReadError;
const VolumeHeader = afs.types.volume.VolumeHeader;
const SpanDescriptor = afs.types.volume.SpanDescriptor;
const UnitRecord = afs.types.catalog.UnitRecord;
const BTreeHeaderRecord = afs.types.btree.HeaderRecord;
const BTreeNodeDescriptor = afs.types.btree.NodeDescriptor;
const constants = afs.constants;
const BTree = btree.BTree;

pub const Reader = struct {
    BlockIO: *efi.protocols.block.BlockIoProtocol,
    BootServices: *efi.services.boot.BootServices,
    PartitionStartLBA: u64,
    PartitionEndLBA: u64,
    VolumeHeader: VolumeHeader,
    CellSize: u32,
    Index: BTree,
    HasSpanOverflow: bool,
    CellBuffer: [*]align(8) u8,
    CellAllocation: efi.types.buffer.AlignedBuffer,

    pub fn initialize(
        block_io: *efi.protocols.block.BlockIoProtocol,
        boot_services: *efi.services.boot.BootServices,
        partition_start_lba: u64,
        partition_end_lba: u64,
    ) ReadError!Reader {
        const block_size = block_io.Media.BlockSize;
        if (block_size < @sizeOf(VolumeHeader) or block_size > constants.sizes.MAXIMUM_CELL_SIZE or
            (block_size & (block_size - 1)) != 0 or partition_start_lba == 0 or
            partition_end_lba < partition_start_lba or partition_end_lba > block_io.Media.LastBlock)
        {
            return ReadError.InvalidVolumeHeader;
        }
        var sector_buffer = efi.buffer.allocate(boot_services, block_size, block_io.Media.IOAlign) orelse return ReadError.AllocationFailed;
        defer efi.buffer.release(boot_services, &sector_buffer);
        const read_status = block_io.ReadBlocks(block_io, block_io.Media.MediaId, partition_start_lba, block_size, sector_buffer.Data);
        if (efi.types.base.isError(read_status)) return ReadError.ReadFailed;

        const header = @as(*const VolumeHeader, @ptrCast(@alignCast(sector_buffer.Data))).*;
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
        var cell_buffer = efi.buffer.allocate(boot_services, header.CellSize, block_io.Media.IOAlign) orelse return ReadError.AllocationFailed;
        errdefer efi.buffer.release(boot_services, &cell_buffer);
        const index_header = try readBtreeHeader(block_io, boot_services, partition_start_lba, partition_end_lba, header.CellSize, header.IndexSpan);
        const index = BTree.initialize(
            block_io,
            boot_services,
            partition_start_lba,
            partition_end_lba,
            header.CellSize,
            header.IndexSpan,
            &index_header,
        ) catch return ReadError.BTreeError;

        return Reader{
            .BlockIO = block_io,
            .BootServices = boot_services,
            .PartitionStartLBA = partition_start_lba,
            .PartitionEndLBA = partition_end_lba,
            .VolumeHeader = header,
            .CellSize = header.CellSize,
            .Index = index,
            .HasSpanOverflow = !header.SpanOverflowSpan.isEmpty(),
            .CellBuffer = cell_buffer.Data,
            .CellAllocation = cell_buffer,
        };
    }

    pub fn deinitialize(self: *Reader) void {
        if (self.CellSize == 0) return;
        self.Index.deinitialize();
        efi.buffer.release(self.BootServices, &self.CellAllocation);
        self.CellSize = 0;
    }

    pub fn openLocation(self: *Reader, path: []const u8) ReadError!UnitRecord {
        var current_node_id: u32 = constants.nodes.ORIGIN_STACK;
        var iterator = utils.path.types.iterator.LocationIterator.init(path);
        while (iterator.next()) |component| {
            var identity_utf16: [@as(afs.types.btree.IndexKey, undefined).Identity.len]u16 = undefined;
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
        if (cell_number >= self.VolumeHeader.TotalCells) return ReadError.InvalidSpan;
        const cell_lba = afs.read.bounds.cellLBA(
            self.PartitionStartLBA,
            self.PartitionEndLBA,
            self.BlockIO.Media.BlockSize,
            self.CellSize,
            cell_number,
            self.CellSize,
        ) orelse return ReadError.InvalidSpan;
        const read_status = self.BlockIO.ReadBlocks(self.BlockIO, self.BlockIO.Media.MediaId, cell_lba, self.CellSize, self.CellBuffer);
        if (efi.types.base.isError(read_status)) return ReadError.ReadFailed;
    }

    pub fn readUnit(self: *Reader, unit: *const UnitRecord, buffer: [*]u8, max_size: u64) ReadError!u64 {
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
            @memcpy(buffer[bytes_read..][0..bytes_to_copy], self.CellBuffer[0..bytes_to_copy]);
            bytes_read += bytes_to_copy;
        }
    }

    pub fn readUnitToAllocated(self: *Reader, unit: *const UnitRecord, max_size: u64) ReadError!struct { Buffer: [*]u8, Size: u64 } {
        const unit_size = unit.DataChannel.LogicalSize;
        if (unit_size == 0 or unit_size > max_size) return ReadError.UnitTooLarge;
        const volume_size = @mulWithOverflow(@as(u64, self.VolumeHeader.TotalCells), @as(u64, self.CellSize));
        if (volume_size[1] != 0 or unit_size > volume_size[0]) return ReadError.UnitTooLarge;
        var buffer: [*]align(8) u8 = undefined;
        const allocation_status = self.BootServices.AllocatePool(.LoaderData, unit_size, &buffer);
        if (efi.types.base.isError(allocation_status)) return ReadError.AllocationFailed;
        errdefer _ = self.BootServices.FreePool(buffer);
        const bytes_read = try self.readUnit(unit, buffer, max_size);
        return .{ .Buffer = buffer, .Size = bytes_read };
    }
};

fn readBtreeHeader(
    block_io: *efi.protocols.block.BlockIoProtocol,
    boot_services: *efi.services.boot.BootServices,
    partition_start_lba: u64,
    partition_end_lba: u64,
    cell_size: u32,
    span: SpanDescriptor,
) ReadError!BTreeHeaderRecord {
    if (cell_size < @sizeOf(BTreeNodeDescriptor) + @sizeOf(BTreeHeaderRecord)) return ReadError.InvalidVolumeHeader;
    const cell_lba = afs.read.bounds.cellLBA(partition_start_lba, partition_end_lba, block_io.Media.BlockSize, cell_size, span.StartCell, cell_size) orelse return ReadError.InvalidSpan;
    var cell_buffer = efi.buffer.allocate(boot_services, cell_size, block_io.Media.IOAlign) orelse return ReadError.AllocationFailed;
    defer efi.buffer.release(boot_services, &cell_buffer);
    const read_status = block_io.ReadBlocks(block_io, block_io.Media.MediaId, cell_lba, cell_size, cell_buffer.Data);
    if (efi.types.base.isError(read_status)) return ReadError.ReadFailed;
    const descriptor: *const BTreeNodeDescriptor = @ptrCast(@alignCast(cell_buffer.Data));
    if (!descriptor.isHeader() or descriptor.RecordCount == 0) return ReadError.InvalidVolumeHeader;
    return @as(*const BTreeHeaderRecord, @ptrCast(@alignCast(cell_buffer.Data + @sizeOf(BTreeNodeDescriptor)))).*;
}
