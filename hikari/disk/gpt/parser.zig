//! Hikari GPT Parser

const constants = @import("hikari").disk.constants;

const efi = @import("hikari").efi;
const errors = @import("hikari").disk.errors;
const types = @import("hikari").disk.types;

const crc = @import("utils").crc;
const math = @import("utils").math;

const ParseError = errors.gpt.ParseError;

pub const Parser = struct {
    BlockIO: *efi.protocols.block.BlockIoProtocol,
    BootServices: *efi.services.boot.BootServices,
    BlockSize: u32,
    Header: types.gpt.Header,
    EntriesBuffer: [*]align(8) u8,
    EntriesAllocation: efi.types.buffer.AlignedBuffer,
    EntriesCount: u32,
    EntrySize: u32,

    pub fn initialize(block_io: *efi.protocols.block.BlockIoProtocol, boot_services: *efi.services.boot.BootServices) ParseError!Parser {
        const block_size = block_io.Media.BlockSize;
        if (block_size < constants.gpt.HEADER_SIZE_MINIMUM or block_size > constants.gpt.HEADER_BUFFER_SIZE or
            (block_size & (block_size - 1)) != 0 or block_io.Media.LastBlock <= constants.gpt.HEADER_LBA)
        {
            return ParseError.InvalidLayout;
        }

        var header_buffer = efi.buffer.allocate(boot_services, block_size, block_io.Media.IOAlign) orelse return ParseError.AllocationFailed;
        defer efi.buffer.release(boot_services, &header_buffer);
        const header_read_status = block_io.ReadBlocks(
            block_io,
            block_io.Media.MediaId,
            constants.gpt.HEADER_LBA,
            block_size,
            header_buffer.Data,
        );

        if (efi.types.base.isError(header_read_status)) {
            return ParseError.ReadFailed;
        }

        const header: *types.gpt.Header = @ptrCast(@alignCast(header_buffer.Data));

        if (header.Signature != constants.gpt.SIGNATURE) {
            return ParseError.InvalidSignature;
        }

        if (header.Revision < constants.gpt.REVISION_1_0) {
            return ParseError.InvalidRevision;
        }

        if (header.HeaderSize < constants.gpt.HEADER_SIZE_MINIMUM or header.HeaderSize > block_size) {
            return ParseError.InvalidHeaderSize;
        }

        const stored_header_crc = header.HeaderCRC32;
        header.HeaderCRC32 = 0;
        const calculated_header_crc = crc.checksum.calculate(header_buffer.Data[0..header.HeaderSize]);
        header.HeaderCRC32 = stored_header_crc;
        if (calculated_header_crc != stored_header_crc) {
            return ParseError.InvalidHeaderCRC;
        }

        if (header.PartitionEntriesCount == 0) {
            return ParseError.NoPartitions;
        }

        if (header.CurrentLBA != constants.gpt.HEADER_LBA or header.BackupLBA > block_io.Media.LastBlock or
            header.BackupLBA == header.CurrentLBA or header.FirstUsableLBA > header.LastUsableLBA or
            header.LastUsableLBA >= block_io.Media.LastBlock or
            header.PartitionEntriesCount > constants.gpt.PARTITION_ENTRIES_COUNT_MAXIMUM or
            header.PartitionEntrySize < @sizeOf(types.gpt.PartitionEntry) or
            (header.PartitionEntrySize % @alignOf(types.gpt.PartitionEntry)) != 0 or
            header.PartitionEntriesLBA < constants.gpt.PARTITION_ENTRIES_START_LBA or
            header.PartitionEntriesLBA > header.FirstUsableLBA)
        {
            return ParseError.InvalidLayout;
        }
        const entries_total_size = @as(u64, header.PartitionEntriesCount) * header.PartitionEntrySize;
        const entries_blocks = math.integer.divideCeil(entries_total_size, block_size);
        if (entries_blocks > header.FirstUsableLBA - header.PartitionEntriesLBA) return ParseError.InvalidLayout;
        const entries_buffer_size = entries_blocks * block_size;

        var entries_buffer = efi.buffer.allocate(boot_services, entries_buffer_size, block_io.Media.IOAlign) orelse return ParseError.AllocationFailed;
        errdefer efi.buffer.release(boot_services, &entries_buffer);

        const entries_read_status = block_io.ReadBlocks(
            block_io,
            block_io.Media.MediaId,
            header.PartitionEntriesLBA,
            entries_buffer_size,
            entries_buffer.Data,
        );

        if (efi.types.base.isError(entries_read_status)) {
            return ParseError.ReadFailed;
        }

        const calculated_entries_crc = crc.checksum.calculate(entries_buffer.Data[0..entries_total_size]);
        if (calculated_entries_crc != header.PartitionEntriesCRC32) {
            return ParseError.InvalidEntriesCRC;
        }

        return Parser{
            .BlockIO = block_io,
            .BootServices = boot_services,
            .BlockSize = block_size,
            .Header = header.*,
            .EntriesBuffer = entries_buffer.Data,
            .EntriesAllocation = entries_buffer,
            .EntriesCount = header.PartitionEntriesCount,
            .EntrySize = header.PartitionEntrySize,
        };
    }

    pub fn deinitialize(self: *Parser) void {
        if (self.EntriesCount == 0) return;
        efi.buffer.release(self.BootServices, &self.EntriesAllocation);
        self.EntriesCount = 0;
    }

    fn validPartition(self: *const Parser, entry: *const types.gpt.PartitionEntry) bool {
        return !entry.isEmpty() and entry.StartingLBA >= self.Header.FirstUsableLBA and
            entry.EndingLBA >= entry.StartingLBA and entry.EndingLBA <= self.Header.LastUsableLBA;
    }

    pub fn findPartitionByType(self: *const Parser, type_guid: efi.types.base.GUID) ?*const types.gpt.PartitionEntry {
        var index: u32 = 0;
        while (index < self.EntriesCount) : (index += 1) {
            const entry = self.getPartitionEntry(index);
            if (!self.validPartition(entry)) {
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
        if (!self.validPartition(entry)) {
            return null;
        }
        return entry;
    }

    pub fn getPartitionEntry(self: *const Parser, index: u32) *const types.gpt.PartitionEntry {
        const offset = @as(usize, index) * self.EntrySize;
        return @ptrCast(@alignCast(self.EntriesBuffer + offset));
    }

    pub fn countValidPartitions(self: *const Parser) u32 {
        var count: u32 = 0;
        var index: u32 = 0;
        while (index < self.EntriesCount) : (index += 1) {
            const entry = self.getPartitionEntry(index);
            if (self.validPartition(entry)) {
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
