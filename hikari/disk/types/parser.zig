//! Hikari GPT Parser

const std = @import("std");

const constants = @import("hikari").disk.constants;
const crc = @import("utils").crc;
const efi = @import("hikari").efi;
const errors = @import("hikari").disk.errors;
const math = @import("utils").math;
const types = @import("hikari").disk.types;

const MediaSnapshot = types.media.MediaSnapshot;
const ParseError = errors.gpt.ParseError;

pub const Parser = struct {
    Media: MediaSnapshot,
    BootServices: *efi.types.services.boot.BootServices,
    Header: types.gpt.Header,
    EntriesBuffer: [*]align(8) u8,
    EntriesAllocation: efi.types.buffer.AlignedBuffer,
    EntriesCount: u32,
    EntrySize: u32,

    pub fn initialize(block_io: *efi.types.protocols.block.BlockIoProtocol, boot_services: *efi.types.services.boot.BootServices) ParseError!Parser {
        const media = MediaSnapshot.capture(block_io) orelse return ParseError.ReadFailed;
        const block_size = media.BlockSize;
        if (block_size < constants.gpt.HEADER_SIZE_MINIMUM or
            (block_size & (block_size - 1)) != 0 or media.LastBlock <= constants.gpt.HEADER_LBA)
        {
            return ParseError.InvalidLayout;
        }

        var header_buffer = efi.buffer.allocate(boot_services, block_size, media.IOAlign) orelse return ParseError.AllocationFailed;
        defer efi.buffer.release(boot_services, &header_buffer);
        if (!media.read(constants.gpt.HEADER_LBA, header_buffer.Data[0..header_buffer.Size])) return ParseError.ReadFailed;

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

        if (header.CurrentLBA != constants.gpt.HEADER_LBA or header.BackupLBA > media.LastBlock or
            header.BackupLBA == header.CurrentLBA or header.FirstUsableLBA > header.LastUsableLBA or
            header.LastUsableLBA >= media.LastBlock or
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
        const rounded_size = std.math.mul(u64, entries_blocks, block_size) catch return ParseError.InvalidLayout;
        const entries_buffer_size = std.math.cast(usize, rounded_size) orelse return ParseError.InvalidLayout;

        var entries_buffer = efi.buffer.allocate(boot_services, entries_buffer_size, media.IOAlign) orelse return ParseError.AllocationFailed;
        errdefer efi.buffer.release(boot_services, &entries_buffer);
        if (!media.read(header.PartitionEntriesLBA, entries_buffer.Data[0..entries_buffer.Size])) return ParseError.ReadFailed;

        const calculated_entries_crc = crc.checksum.calculate(entries_buffer.Data[0..entries_total_size]);
        if (calculated_entries_crc != header.PartitionEntriesCRC32) {
            return ParseError.InvalidEntriesCRC;
        }

        return Parser{
            .Media = media,
            .BootServices = boot_services,
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
