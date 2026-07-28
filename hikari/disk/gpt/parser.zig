//! Hikari GPT Parser

const constants = @import("hikari").disk.constants;
const crc = @import("hikari").disk.gpt.crc;
const efi = @import("hikari").efi;
const errors = @import("hikari").disk.errors;
const types = @import("hikari").disk.types;

const ParseError = errors.gpt.ParseError;

pub const Parser = struct {
    BlockIO: *efi.protocols.block.BlockIoProtocol,
    BlockSize: u32,
    Header: types.gpt.Header,
    EntriesBuffer: [*]u8,
    EntriesCount: u32,
    EntrySize: u32,

    pub fn initialize(block_io: *efi.protocols.block.BlockIoProtocol, boot_services: *efi.services.boot.BootServices) ParseError!Parser {
        const block_size = block_io.Media.BlockSize;

        var header_buffer: [constants.gpt.HEADER_BUFFER_SIZE]u8 align(8) = undefined;
        const header_read_status = block_io.ReadBlocks(
            block_io,
            block_io.Media.MediaId,
            constants.gpt.HEADER_LBA,
            block_size,
            &header_buffer,
        );

        if (efi.types.base.isError(header_read_status)) {
            return ParseError.ReadFailed;
        }

        const header: *const types.gpt.Header = @ptrCast(@alignCast(&header_buffer));

        if (header.Signature != constants.gpt.SIGNATURE) {
            return ParseError.InvalidSignature;
        }

        if (header.Revision < constants.gpt.REVISION_1_0) {
            return ParseError.InvalidRevision;
        }

        if (header.HeaderSize < constants.gpt.HEADER_SIZE_MINIMUM) {
            return ParseError.InvalidHeaderSize;
        }

        const stored_header_crc = header.HeaderCRC32;
        var header_for_crc = header_buffer;
        const header_pointer: *types.gpt.Header = @ptrCast(@alignCast(&header_for_crc));
        header_pointer.HeaderCRC32 = 0;

        const calculated_header_crc = crc.calculateCRC32(header_for_crc[0..header.HeaderSize]);
        if (calculated_header_crc != stored_header_crc) {
            return ParseError.InvalidHeaderCRC;
        }

        if (header.PartitionEntriesCount == 0) {
            return ParseError.NoPartitions;
        }

        const entries_total_size = header.PartitionEntriesCount * header.PartitionEntrySize;
        const entries_blocks = (entries_total_size + block_size - 1) / block_size;
        const entries_buffer_size = entries_blocks * block_size;

        var entries_buffer: [*]align(8) u8 = undefined;
        const allocation_status = boot_services.AllocatePool(
            .LoaderData,
            entries_buffer_size,
            &entries_buffer,
        );

        if (efi.types.base.isError(allocation_status)) {
            return ParseError.ReadFailed;
        }

        const entries_read_status = block_io.ReadBlocks(
            block_io,
            block_io.Media.MediaId,
            header.PartitionEntriesLBA,
            entries_buffer_size,
            entries_buffer,
        );

        if (efi.types.base.isError(entries_read_status)) {
            return ParseError.ReadFailed;
        }

        const calculated_entries_crc = crc.calculateCRC32(entries_buffer[0..entries_total_size]);
        if (calculated_entries_crc != header.PartitionEntriesCRC32) {
            return ParseError.InvalidEntriesCRC;
        }

        return Parser{
            .BlockIO = block_io,
            .BlockSize = block_size,
            .Header = header.*,
            .EntriesBuffer = entries_buffer,
            .EntriesCount = header.PartitionEntriesCount,
            .EntrySize = header.PartitionEntrySize,
        };
    }

    pub fn findPartitionByType(self: *const Parser, type_guid: efi.types.base.GUID) ?*const types.gpt.PartitionEntry {
        var index: u32 = 0;
        while (index < self.EntriesCount) : (index += 1) {
            const entry = self.getPartitionEntry(index);
            if (entry.isEmpty()) {
                continue;
            }
            if (entry.isType(type_guid)) {
                return entry;
            }
        }
        return null;
    }

    pub fn findPartitionByIndex(self: *const Parser, index: u32) ?*const types.gpt.PartitionEntry {
        if (index >= self.EntriesCount) {
            return null;
        }
        const entry = self.getPartitionEntry(index);
        if (entry.isEmpty()) {
            return null;
        }
        return entry;
    }

    pub fn getPartitionEntry(self: *const Parser, index: u32) *const types.gpt.PartitionEntry {
        const offset = index * self.EntrySize;
        return @ptrCast(@alignCast(self.EntriesBuffer + offset));
    }

    pub fn countValidPartitions(self: *const Parser) u32 {
        var count: u32 = 0;
        var index: u32 = 0;
        while (index < self.EntriesCount) : (index += 1) {
            const entry = self.getPartitionEntry(index);
            if (!entry.isEmpty()) {
                count += 1;
            }
        }
        return count;
    }

    pub fn getDiskGUID(self: *const Parser) efi.types.base.GUID {
        return self.Header.DiskGUID;
    }

    pub fn getFirstUsableLBA(self: *const Parser) u64 {
        return self.Header.FirstUsableLBA;
    }

    pub fn getLastUsableLBA(self: *const Parser) u64 {
        return self.Header.LastUsableLBA;
    }
};
