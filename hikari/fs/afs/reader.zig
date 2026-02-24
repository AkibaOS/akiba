//! Hikari AFS Reader

const efi = @import("../../efi/efi.zig");
const constants = @import("constants.zig");
const types = @import("types.zig");
const btree = @import("btree.zig");

pub const ReadError = error{
    invalid_volume_header,
    read_failed,
    allocation_failed,
    not_found,
    not_a_stack,
    unit_too_large,
    invalid_span,
    btree_error,
};

pub const Reader = struct {
    block_io: *efi.protocols.BlockIoProtocol,
    boot_services: *efi.services.BootServices,
    partition_start_lba: u64,
    volume_header: types.VolumeHeader,
    cell_size: u32,
    index: btree.BTree,
    span_overflow: ?btree.BTree,
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
            return ReadError.allocation_failed;
        }

        const read_status = block_io.read_blocks(
            block_io,
            block_io.media.media_id,
            partition_start_lba,
            block_size,
            sector_buffer,
        );
        if (efi.types.is_error(read_status)) {
            return ReadError.read_failed;
        }

        const volume_header: *const types.VolumeHeader = @ptrCast(@alignCast(sector_buffer));
        if (!volume_header.is_valid()) {
            return ReadError.invalid_volume_header;
        }

        const cell_size = volume_header.cell_size;

        var cell_buffer: [*]align(8) u8 = undefined;
        alloc_status = boot_services.allocate_pool(
            .loader_data,
            cell_size,
            &cell_buffer,
        );
        if (efi.types.is_error(alloc_status)) {
            return ReadError.allocation_failed;
        }

        const index_header = try read_btree_header(
            block_io,
            boot_services,
            partition_start_lba,
            cell_size,
            volume_header.index_span,
        );

        const index = btree.BTree.initialize(
            block_io,
            boot_services,
            partition_start_lba,
            cell_size,
            volume_header.index_span,
            index_header,
        ) catch {
            return ReadError.btree_error;
        };

        var span_overflow: ?btree.BTree = null;
        if (!volume_header.span_overflow_span.is_empty()) {
            const span_overflow_header = try read_btree_header(
                block_io,
                boot_services,
                partition_start_lba,
                cell_size,
                volume_header.span_overflow_span,
            );

            span_overflow = btree.BTree.initialize(
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

    pub fn open_location(self: *Reader, location: []const u8) ReadError!types.UnitRecord {
        var current_node_id: u32 = constants.special_node_id_origin_stack;

        var start: usize = 0;
        if (location.len > 0 and (location[0] == '/' or location[0] == '\\')) {
            start = 1;
        }

        var iter_start = start;
        var last_unit: ?types.UnitRecord = null;

        while (iter_start < location.len) {
            var iter_end = iter_start;
            while (iter_end < location.len and location[iter_end] != '/' and location[iter_end] != '\\') {
                iter_end += 1;
            }

            if (iter_end == iter_start) {
                iter_start = iter_end + 1;
                continue;
            }

            const component = location[iter_start..iter_end];

            var identity_utf16: [constants.max_identity_length]u16 = undefined;
            var identity_len: usize = 0;
            for (component) |byte| {
                identity_utf16[identity_len] = byte;
                identity_len += 1;
            }
            const identity = identity_utf16[0..identity_len];

            const stack_record = self.index.search_index_for_stack(current_node_id, identity) catch {
                return ReadError.btree_error;
            };

            if (stack_record) |stack| {
                current_node_id = stack.node_id;
                iter_start = iter_end + 1;
                continue;
            }

            const unit_record = self.index.search_index(current_node_id, identity) catch {
                return ReadError.btree_error;
            };

            if (unit_record) |unit| {
                if (iter_end >= location.len) {
                    last_unit = unit.*;
                    break;
                } else {
                    return ReadError.not_a_stack;
                }
            }

            return ReadError.not_found;
        }

        if (last_unit) |unit| {
            return unit;
        }

        return ReadError.not_found;
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
            return ReadError.read_failed;
        }
    }

    pub fn read_unit(self: *Reader, unit: *const types.UnitRecord, buffer: [*]u8, max_size: u64) ReadError!u64 {
        const channel = &unit.data_channel;
        const unit_size = channel.logical_size;

        if (unit_size > max_size) {
            return ReadError.unit_too_large;
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

    fn read_span_data(self: *Reader, span: *const types.SpanDescriptor, buffer: [*]u8, size: u64) ReadError!void {
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
        unit: *const types.UnitRecord,
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

    pub fn read_unit_to_allocated(self: *Reader, unit: *const types.UnitRecord) ReadError!struct { buffer: [*]u8, size: u64 } {
        const unit_size = unit.data_channel.logical_size;

        var buffer: [*]align(8) u8 = undefined;
        const alloc_status = self.boot_services.allocate_pool(
            .loader_data,
            unit_size,
            &buffer,
        );
        if (efi.types.is_error(alloc_status)) {
            return ReadError.allocation_failed;
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
    span: types.SpanDescriptor,
) ReadError!*const types.BTreeHeaderRecord {
    var cell_buffer: [*]align(8) u8 = undefined;
    const alloc_status = boot_services.allocate_pool(
        .loader_data,
        cell_size,
        &cell_buffer,
    );
    if (efi.types.is_error(alloc_status)) {
        return ReadError.allocation_failed;
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
        return ReadError.read_failed;
    }

    const node_desc: *const types.BTreeNodeDescriptor = @ptrCast(@alignCast(cell_buffer));
    if (!node_desc.is_header()) {
        return ReadError.read_failed;
    }

    const header_offset = @sizeOf(types.BTreeNodeDescriptor);
    return @ptrCast(@alignCast(cell_buffer + header_offset));
}
