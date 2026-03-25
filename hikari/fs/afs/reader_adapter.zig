//! Hikari AFS Reader

const efi = @import("../../efi/efi.zig");
const shared_afs = @import("../../../shared/fs/afs/afs.zig");
const btree_adapter = @import("btree_adapter.zig");

// Import shared types
const VolumeHeader = shared_afs.VolumeHeader;
const SpanDescriptor = shared_afs.SpanDescriptor;
const ChannelInfo = shared_afs.ChannelInfo;
const UnitRecord = shared_afs.UnitRecord;
const BTreeHeaderRecord = shared_afs.BTreeHeaderRecord;
const BTreeNodeDescriptor = shared_afs.BTreeNodeDescriptor;

const constants = shared_afs.constants;
const read_ops = shared_afs.read;

const BTree = btree_adapter.BTree;

pub const ReadError = error{
    InvalidVolumeHeader,
    ReadFailed,
    AllocationFailed,
    NotFound,
    NotAStack,
    UnitTooLarge,
    InvalidSpan,
    BTreeError,
};

pub const Reader = struct {
    block_io: *efi.protocols.BlockIoProtocol,
    boot_services: *efi.services.BootServices,
    partition_start_lba: u64,
    volume_header: VolumeHeader,
    cell_size: u32,
    index: BTree,
    span_overflow: ?BTree,
    cell_buffer: [*]u8,

    pub fn initialize(
        block_io: *efi.protocols.BlockIoProtocol,
        boot_services: *efi.services.BootServices,
        partition_start_lba: u64,
    ) ReadError!Reader {
        const block_size = block_io.media.block_size;

        var sector_buffer: [*]align(8) u8 = undefined;
        var alloc_status = boot_services.allocate_pool(
            .loader_data,
            block_size,
            &sector_buffer,
        );
        if (efi.types.is_error(alloc_status)) {
            return ReadError.AllocationFailed;
        }

        const read_status = block_io.read_blocks(
            block_io,
            block_io.media.media_id,
            partition_start_lba,
            block_size,
            sector_buffer,
        );
        if (efi.types.is_error(read_status)) {
            return ReadError.ReadFailed;
        }

        const volume_header: *const VolumeHeader = @ptrCast(@alignCast(sector_buffer));
        if (!volume_header.is_valid()) {
            return ReadError.InvalidVolumeHeader;
        }

        const cell_size = volume_header.cell_size;

        var cell_buffer: [*]align(8) u8 = undefined;
        alloc_status = boot_services.allocate_pool(
            .loader_data,
            cell_size,
            &cell_buffer,
        );
        if (efi.types.is_error(alloc_status)) {
            return ReadError.AllocationFailed;
        }

        const index_header = try read_btree_header(
            block_io,
            boot_services,
            partition_start_lba,
            cell_size,
            volume_header.index_span,
        );

        const index = BTree.initialize(
            block_io,
            boot_services,
            partition_start_lba,
            cell_size,
            volume_header.index_span,
            index_header,
        ) catch {
            return ReadError.BTreeError;
        };

        var span_overflow: ?BTree = null;
        if (!volume_header.span_overflow_span.is_empty()) {
            const span_overflow_header = try read_btree_header(
                block_io,
                boot_services,
                partition_start_lba,
                cell_size,
                volume_header.span_overflow_span,
            );

            span_overflow = BTree.initialize(
                block_io,
                boot_services,
                partition_start_lba,
                cell_size,
                volume_header.span_overflow_span,
                span_overflow_header,
            ) catch null;
        }

        const header_copy = volume_header.*;

        _ = boot_services.free_pool(sector_buffer);

        return Reader{
            .block_io = block_io,
            .boot_services = boot_services,
            .partition_start_lba = partition_start_lba,
            .volume_header = header_copy,
            .cell_size = cell_size,
            .index = index,
            .span_overflow = span_overflow,
            .cell_buffer = cell_buffer,
        };
    }

    pub fn open_location(self: *Reader, location: []const u8) ReadError!UnitRecord {
        var current_node_id: u32 = constants.nodes.origin_stack;

        var iter = read_ops.LocationIterator.init(location);
        var last_unit: ?UnitRecord = null;

        while (iter.next()) |component| {
            var identity_utf16: [constants.max_identity_length]u16 = undefined;
            const identity_len = read_ops.component_to_identity(component, &identity_utf16);
            const identity = identity_utf16[0..identity_len];

            const stack_record = self.index.search_index_for_stack(current_node_id, identity) catch {
                return ReadError.BTreeError;
            };

            if (stack_record) |stack| {
                current_node_id = stack.node_id;
                continue;
            }

            const unit_record = self.index.search_index(current_node_id, identity) catch {
                return ReadError.BTreeError;
            };

            if (unit_record) |unit| {
                // Check if this is the last component
                if (iter.next() == null) {
                    last_unit = unit.*;
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

    pub fn read_cell(self: *Reader, cell_number: u64) ReadError!void {
        const cell_lba = self.partition_start_lba +
            (cell_number * self.cell_size / self.block_io.media.block_size);

        const read_status = self.block_io.read_blocks(
            self.block_io,
            self.block_io.media.media_id,
            cell_lba,
            self.cell_size,
            self.cell_buffer,
        );
        if (efi.types.is_error(read_status)) {
            return ReadError.ReadFailed;
        }
    }

    pub fn read_unit(self: *Reader, unit: *const UnitRecord, buffer: [*]u8, max_size: u64) ReadError!u64 {
        const channel = &unit.data_channel;
        const unit_size = channel.logical_size;

        if (unit_size > max_size) {
            return ReadError.UnitTooLarge;
        }

        var bytes_read: u64 = 0;
        var span_index: usize = 0;

        while (bytes_read < unit_size and span_index < constants.span_inline_count) {
            const span = channel.get_span(span_index);
            if (span == null) {
                break;
            }

            const span_bytes = span.?.byte_size(self.cell_size);
            const bytes_remaining = unit_size - bytes_read;
            const bytes_to_read = if (bytes_remaining < span_bytes) bytes_remaining else span_bytes;

            try self.read_span_data(span.?, buffer + bytes_read, bytes_to_read);
            bytes_read += bytes_to_read;
            span_index += 1;
        }

        if (bytes_read < unit_size and self.span_overflow != null) {
            bytes_read = try self.read_overflow_spans(unit, buffer, bytes_read, unit_size);
        }

        return bytes_read;
    }

    fn read_span_data(self: *Reader, span: *const SpanDescriptor, buffer: [*]u8, size: u64) ReadError!void {
        var bytes_read: u64 = 0;
        var current_cell = span.start_cell;

        while (bytes_read < size) {
            try self.read_cell(current_cell);

            const bytes_remaining = size - bytes_read;
            const bytes_to_copy = if (bytes_remaining < self.cell_size) bytes_remaining else self.cell_size;

            var i: u64 = 0;
            while (i < bytes_to_copy) : (i += 1) {
                buffer[bytes_read + i] = self.cell_buffer[i];
            }

            bytes_read += bytes_to_copy;
            current_cell += 1;
        }
    }

    fn read_overflow_spans(
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

    pub fn read_unit_to_allocated(self: *Reader, unit: *const UnitRecord) ReadError!struct { buffer: [*]u8, size: u64 } {
        const unit_size = unit.data_channel.logical_size;

        var buffer: [*]align(8) u8 = undefined;
        const alloc_status = self.boot_services.allocate_pool(
            .loader_data,
            unit_size,
            &buffer,
        );
        if (efi.types.is_error(alloc_status)) {
            return ReadError.AllocationFailed;
        }

        const bytes_read = try self.read_unit(unit, buffer, unit_size);
        return .{ .buffer = buffer, .size = bytes_read };
    }
};

fn read_btree_header(
    block_io: *efi.protocols.BlockIoProtocol,
    boot_services: *efi.services.BootServices,
    partition_start_lba: u64,
    cell_size: u32,
    span: SpanDescriptor,
) ReadError!*const BTreeHeaderRecord {
    var cell_buffer: [*]align(8) u8 = undefined;
    const alloc_status = boot_services.allocate_pool(
        .loader_data,
        cell_size,
        &cell_buffer,
    );
    if (efi.types.is_error(alloc_status)) {
        return ReadError.AllocationFailed;
    }

    const cell_lba = partition_start_lba +
        (span.start_cell * cell_size / block_io.media.block_size);

    const read_status = block_io.read_blocks(
        block_io,
        block_io.media.media_id,
        cell_lba,
        cell_size,
        cell_buffer,
    );
    if (efi.types.is_error(read_status)) {
        return ReadError.ReadFailed;
    }

    const node_desc: *const BTreeNodeDescriptor = @ptrCast(@alignCast(cell_buffer));
    if (!node_desc.is_header()) {
        return ReadError.ReadFailed;
    }

    const header_offset = @sizeOf(BTreeNodeDescriptor);
    return @ptrCast(@alignCast(cell_buffer + header_offset));
}
