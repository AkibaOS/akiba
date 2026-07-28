//! Hikari AFS Reader

const afs = @import("shared").afs;
const btree = @import("hikari").fs.afs.btree;
const efi = @import("hikari").efi;
const errors = @import("hikari").fs.errors;

const ReadError = errors.afs.ReadError;
const VolumeHeader = afs.types.volume.VolumeHeader;
const SpanDescriptor = afs.types.volume.SpanDescriptor;
const UnitRecord = afs.types.catalog.UnitRecord;
const BTreeHeaderRecord = afs.types.btree.HeaderRecord;
const BTreeNodeDescriptor = afs.types.btree.NodeDescriptor;
const constants = afs.constants;
const location = afs.read.location;
const BTree = btree.BTree;

pub const Reader = struct {
    BlockIO: *efi.protocols.block.BlockIoProtocol,
    BootServices: *efi.services.boot.BootServices,
    PartitionStartLBA: u64,
    VolumeHeader: VolumeHeader,
    CellSize: u32,
    Index: BTree,
    SpanOverflow: ?BTree,
    CellBuffer: [*]u8,

    pub fn initialize(
        block_io: *efi.protocols.block.BlockIoProtocol,
        boot_services: *efi.services.boot.BootServices,
        partition_start_lba: u64,
    ) ReadError!Reader {
        const block_size = block_io.Media.BlockSize;

        var sector_buffer: [*]align(8) u8 = undefined;
        var allocation_status = boot_services.AllocatePool(
            .LoaderData,
            block_size,
            &sector_buffer,
        );
        if (efi.types.base.isError(allocation_status)) {
            return ReadError.AllocationFailed;
        }

        const read_status = block_io.ReadBlocks(
            block_io,
            block_io.Media.MediaId,
            partition_start_lba,
            block_size,
            sector_buffer,
        );
        if (efi.types.base.isError(read_status)) {
            return ReadError.ReadFailed;
        }

        const volume_header: *const VolumeHeader = @ptrCast(@alignCast(sector_buffer));
        if (!volume_header.isValid()) {
            return ReadError.InvalidVolumeHeader;
        }

        const cell_size = volume_header.CellSize;

        var cell_buffer: [*]align(8) u8 = undefined;
        allocation_status = boot_services.AllocatePool(
            .LoaderData,
            cell_size,
            &cell_buffer,
        );
        if (efi.types.base.isError(allocation_status)) {
            return ReadError.AllocationFailed;
        }

        const index_header = try readBtreeHeader(
            block_io,
            boot_services,
            partition_start_lba,
            cell_size,
            volume_header.IndexSpan,
        );

        const index = BTree.initialize(
            block_io,
            boot_services,
            partition_start_lba,
            cell_size,
            volume_header.IndexSpan,
            index_header,
        ) catch {
            return ReadError.BTreeError;
        };

        var span_overflow: ?BTree = null;
        if (!volume_header.SpanOverflowSpan.isEmpty()) {
            const span_overflow_header = try readBtreeHeader(
                block_io,
                boot_services,
                partition_start_lba,
                cell_size,
                volume_header.SpanOverflowSpan,
            );

            span_overflow = BTree.initialize(
                block_io,
                boot_services,
                partition_start_lba,
                cell_size,
                volume_header.SpanOverflowSpan,
                span_overflow_header,
            ) catch null;
        }

        const header_copy = volume_header.*;

        _ = boot_services.FreePool(sector_buffer);

        return Reader{
            .BlockIO = block_io,
            .BootServices = boot_services,
            .PartitionStartLBA = partition_start_lba,
            .VolumeHeader = header_copy,
            .CellSize = cell_size,
            .Index = index,
            .SpanOverflow = span_overflow,
            .CellBuffer = cell_buffer,
        };
    }

    pub fn openLocation(self: *Reader, path: []const u8) ReadError!UnitRecord {
        var current_node_id: u32 = constants.nodes.ORIGIN_STACK;

        var iterator = location.LocationIterator.init(path);
        var last_unit: ?UnitRecord = null;

        while (iterator.next()) |component| {
            var identity_utf16: [constants.sizes.MAX_IDENTITY_LENGTH]u16 = undefined;
            const identity_length = location.componentToIdentity(component, &identity_utf16);
            const identity = identity_utf16[0..identity_length];

            const stack_record = self.Index.searchIndexForStack(current_node_id, identity) catch {
                return ReadError.BTreeError;
            };

            if (stack_record) |found_stack| {
                current_node_id = found_stack.NodeId;
                continue;
            }

            const unit_record = self.Index.searchIndex(current_node_id, identity) catch {
                return ReadError.BTreeError;
            };

            if (unit_record) |found_unit| {
                if (iterator.next() == null) {
                    last_unit = found_unit.*;
                    break;
                } else {
                    return ReadError.NotAStack;
                }
            }

            return ReadError.NotFound;
        }

        if (last_unit) |unit| {
            return unit;
        }

        return ReadError.NotFound;
    }

    pub fn readCell(self: *Reader, cell_number: u64) ReadError!void {
        const cell_lba = self.PartitionStartLBA +
            (cell_number * self.CellSize / self.BlockIO.Media.BlockSize);

        const read_status = self.BlockIO.ReadBlocks(
            self.BlockIO,
            self.BlockIO.Media.MediaId,
            cell_lba,
            self.CellSize,
            self.CellBuffer,
        );
        if (efi.types.base.isError(read_status)) {
            return ReadError.ReadFailed;
        }
    }

    pub fn readUnit(self: *Reader, unit: *const UnitRecord, buffer: [*]u8, max_size: u64) ReadError!u64 {
        const channel = &unit.DataChannel;
        const unit_size = channel.LogicalSize;

        if (unit_size > max_size) {
            return ReadError.UnitTooLarge;
        }

        var bytes_read: u64 = 0;
        var span_index: usize = 0;

        while (bytes_read < unit_size and span_index < constants.sizes.SPAN_INLINE_COUNT) {
            const span = channel.getSpan(span_index);
            if (span == null) {
                break;
            }

            const span_bytes = span.?.byteSize(self.CellSize);
            const bytes_remaining = unit_size - bytes_read;
            const bytes_to_read = if (bytes_remaining < span_bytes) bytes_remaining else span_bytes;

            try self.readSpanData(span.?, buffer + bytes_read, bytes_to_read);
            bytes_read += bytes_to_read;
            span_index += 1;
        }

        if (bytes_read < unit_size and self.SpanOverflow != null) {
            bytes_read = try self.readOverflowSpans(unit, buffer, bytes_read, unit_size);
        }

        return bytes_read;
    }

    fn readSpanData(self: *Reader, span: *const SpanDescriptor, buffer: [*]u8, size: u64) ReadError!void {
        var bytes_read: u64 = 0;
        var current_cell = span.StartCell;

        while (bytes_read < size) {
            try self.readCell(current_cell);

            const bytes_remaining = size - bytes_read;
            const bytes_to_copy = if (bytes_remaining < self.CellSize) bytes_remaining else self.CellSize;

            var index: u64 = 0;
            while (index < bytes_to_copy) : (index += 1) {
                buffer[bytes_read + index] = self.CellBuffer[index];
            }

            bytes_read += bytes_to_copy;
            current_cell += 1;
        }
    }

    fn readOverflowSpans(
        self: *Reader,
        unit: *const UnitRecord,
        buffer: [*]u8,
        start_offset: u64,
        total_size: u64,
    ) ReadError!u64 {
        _ = self;
        _ = unit;
        _ = buffer;
        _ = start_offset;
        return total_size;
    }

    pub fn readUnitToAllocated(self: *Reader, unit: *const UnitRecord) ReadError!struct { Buffer: [*]u8, Size: u64 } {
        const unit_size = unit.DataChannel.LogicalSize;

        var buffer: [*]align(8) u8 = undefined;
        const allocation_status = self.BootServices.AllocatePool(
            .LoaderData,
            unit_size,
            &buffer,
        );
        if (efi.types.base.isError(allocation_status)) {
            return ReadError.AllocationFailed;
        }

        const bytes_read = try self.readUnit(unit, buffer, unit_size);
        return .{ .Buffer = buffer, .Size = bytes_read };
    }
};

fn readBtreeHeader(
    block_io: *efi.protocols.block.BlockIoProtocol,
    boot_services: *efi.services.boot.BootServices,
    partition_start_lba: u64,
    cell_size: u32,
    span: SpanDescriptor,
) ReadError!*const BTreeHeaderRecord {
    var cell_buffer: [*]align(8) u8 = undefined;
    const allocation_status = boot_services.AllocatePool(
        .LoaderData,
        cell_size,
        &cell_buffer,
    );
    if (efi.types.base.isError(allocation_status)) {
        return ReadError.AllocationFailed;
    }

    const cell_lba = partition_start_lba +
        (span.StartCell * cell_size / block_io.Media.BlockSize);

    const read_status = block_io.ReadBlocks(
        block_io,
        block_io.Media.MediaId,
        cell_lba,
        cell_size,
        cell_buffer,
    );
    if (efi.types.base.isError(read_status)) {
        return ReadError.ReadFailed;
    }

    const node_descriptor: *const BTreeNodeDescriptor = @ptrCast(@alignCast(cell_buffer));
    if (!node_descriptor.isHeader()) {
        return ReadError.ReadFailed;
    }

    const header_offset = @sizeOf(BTreeNodeDescriptor);
    return @ptrCast(@alignCast(cell_buffer + header_offset));
}
