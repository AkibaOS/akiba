//! Hikari GPT Parser

const efi = @import("../../efi/efi.zig");
const constants = @import("constants.zig");
const types = @import("types.zig");

pub const ParseError = error{
    read_failed,
    invalid_protective_mbr,
    invalid_signature,
    invalid_revision,
    invalid_header_size,
    invalid_header_crc,
    invalid_entries_crc,
    no_partitions,
    partition_not_found,
};

pub const Parser = struct {
    block_io: *efi.protocols.BlockIoProtocol,
    block_size: u32,
    header: types.Header,
    entries_buffer: [*]u8,
    entries_count: u32,
    entry_size: u32,

    pub fn initialize(block_io: *efi.protocols.BlockIoProtocol, boot_services: *efi.services.BootServices) ParseError!Parser {
        const block_size = block_io.media.block_size;

        var header_buffer: [512]u8 align(8) = undefined;
        const header_read_status = block_io.read_blocks(
            block_io,
            block_io.media.media_id,
            constants.header_lba,
            block_size,
            &header_buffer,
        );

        if (efi.types.is_error(header_read_status)) {
            return ParseError.read_failed;
        }

        const header: *const types.Header = @ptrCast(@alignCast(&header_buffer));

        if (header.signature != constants.signature) {
            return ParseError.invalid_signature;
        }

        if (header.revision < constants.revision_1_0) {
            return ParseError.invalid_revision;
        }

        if (header.header_size < constants.header_size_minimum) {
            return ParseError.invalid_header_size;
        }

        const stored_header_crc = header.header_crc32;
        var header_for_crc = header_buffer;
        const header_ptr: *types.Header = @ptrCast(@alignCast(&header_for_crc));
        header_ptr.header_crc32 = 0;

        const calculated_header_crc = calculate_crc32(header_for_crc[0..header.header_size]);
        if (calculated_header_crc != stored_header_crc) {
            return ParseError.invalid_header_crc;
        }

        if (header.partition_entries_count == 0) {
            return ParseError.no_partitions;
        }

        const entries_total_size = header.partition_entries_count * header.partition_entry_size;
        const entries_blocks = (entries_total_size + block_size - 1) / block_size;
        const entries_buffer_size = entries_blocks * block_size;

        var entries_buffer: [*]align(8) u8 = undefined;
        const alloc_status = boot_services.allocate_pool(
            .loader_data,
            entries_buffer_size,
            &entries_buffer,
        );

        if (efi.types.is_error(alloc_status)) {
            return ParseError.read_failed;
        }

        const entries_read_status = block_io.read_blocks(
            block_io,
            block_io.media.media_id,
            header.partition_entries_lba,
            entries_buffer_size,
            entries_buffer,
        );

        if (efi.types.is_error(entries_read_status)) {
            return ParseError.read_failed;
        }

        const calculated_entries_crc = calculate_crc32(entries_buffer[0..entries_total_size]);
        if (calculated_entries_crc != header.partition_entries_crc32) {
            return ParseError.invalid_entries_crc;
        }

        return Parser{
            .block_io = block_io,
            .block_size = block_size,
            .header = header.*,
            .entries_buffer = entries_buffer,
            .entries_count = header.partition_entries_count,
            .entry_size = header.partition_entry_size,
        };
    }

    pub fn find_partition_by_type(self: *const Parser, type_guid: efi.types.Guid) ?*const types.PartitionEntry {
        var index: u32 = 0;
        while (index < self.entries_count) : (index += 1) {
            const entry = self.get_partition_entry(index);
            if (entry.is_empty()) {
                continue;
            }
            if (entry.is_type(type_guid)) {
                return entry;
            }
        }
        return null;
    }

    pub fn find_partition_by_index(self: *const Parser, index: u32) ?*const types.PartitionEntry {
        if (index >= self.entries_count) {
            return null;
        }
        const entry = self.get_partition_entry(index);
        if (entry.is_empty()) {
            return null;
        }
        return entry;
    }

    pub fn get_partition_entry(self: *const Parser, index: u32) *const types.PartitionEntry {
        const offset = index * self.entry_size;
        return @ptrCast(@alignCast(self.entries_buffer + offset));
    }

    pub fn count_valid_partitions(self: *const Parser) u32 {
        var count: u32 = 0;
        var index: u32 = 0;
        while (index < self.entries_count) : (index += 1) {
            const entry = self.get_partition_entry(index);
            if (!entry.is_empty()) {
                count += 1;
            }
        }
        return count;
    }

    pub fn get_disk_guid(self: *const Parser) efi.types.Guid {
        return self.header.disk_guid;
    }

    pub fn get_first_usable_lba(self: *const Parser) u64 {
        return self.header.first_usable_lba;
    }

    pub fn get_last_usable_lba(self: *const Parser) u64 {
        return self.header.last_usable_lba;
    }
};

const crc32_table: [256]u32 = generate_crc32_table();

fn generate_crc32_table() [256]u32 {
    var table: [256]u32 = undefined;
    var index: u32 = 0;
    while (index < 256) : (index += 1) {
        var crc: u32 = index;
        var bit: u32 = 0;
        while (bit < 8) : (bit += 1) {
            if ((crc & 1) != 0) {
                crc = (crc >> 1) ^ 0xEDB88320;
            } else {
                crc = crc >> 1;
            }
        }
        table[index] = crc;
    }
    return table;
}

pub fn calculate_crc32(data: []const u8) u32 {
    var crc: u32 = 0xFFFFFFFF;
    for (data) |byte| {
        const table_index = (crc ^ byte) & 0xFF;
        crc = (crc >> 8) ^ crc32_table[table_index];
    }
    return crc ^ 0xFFFFFFFF;
}
