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
    BootServices: *efi.types.services.boot.BootServices,
    Media: MediaSnapshot = undefined,
    Header: types.gpt.Header = undefined,
    Scratch: efi.types.buffer.claims.AlignedBuffer = .{},
    EntriesCount: u32 = 0,
    EntrySize: u32 = 0,

    pub fn initialize(self: *Parser, block_io: *efi.types.protocols.block.BlockIoProtocol) ParseError!void {
        if (!self.Scratch.Pool.isEmpty()) return ParseError.AllocationFailed;
        const media = MediaSnapshot.capture(block_io) orelse return ParseError.ReadFailed;
        const block_size = media.BlockSize;
        if (block_size < constants.gpt.HEADER_SIZE_MINIMUM or
            (block_size & (block_size - 1)) != 0 or media.LastBlock <= constants.gpt.HEADER_LBA)
        {
            return ParseError.InvalidLayout;
        }

        if (!efi.buffer.allocate(self.BootServices, block_size, media.IOAlign, &self.Scratch)) return ParseError.AllocationFailed;
        const header_bytes = self.Scratch.Data[0..self.Scratch.Size];
        if (!media.read(constants.gpt.HEADER_LBA, header_bytes)) return ParseError.ReadFailed;

        const header: *types.gpt.Header = @ptrCast(@alignCast(header_bytes.ptr));

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
        const calculated_header_crc = crc.checksum.calculate(header_bytes[0..header.HeaderSize]);
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

        const checked_header = header.*;
        if (!efi.buffer.release(self.BootServices, &self.Scratch)) return ParseError.ReleaseFailed;
        if (!efi.buffer.allocate(self.BootServices, entries_buffer_size, media.IOAlign, &self.Scratch)) return ParseError.AllocationFailed;
        const entries = self.Scratch.Data[0..self.Scratch.Size];
        if (!media.read(checked_header.PartitionEntriesLBA, entries)) return ParseError.ReadFailed;

        const calculated_entries_crc = crc.checksum.calculate(entries[0..entries_total_size]);
        if (calculated_entries_crc != checked_header.PartitionEntriesCRC32) return ParseError.InvalidEntriesCRC;

        self.Media = media;
        self.Header = checked_header;
        self.EntriesCount = checked_header.PartitionEntriesCount;
        self.EntrySize = checked_header.PartitionEntrySize;
    }

    pub fn deinitialize(self: *Parser) bool {
        self.EntriesCount = 0;
        self.EntrySize = 0;
        return efi.buffer.release(self.BootServices, &self.Scratch);
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

    fn getPartitionEntry(self: *const Parser, index: u32) *const types.gpt.PartitionEntry {
        const offset = @as(usize, index) * self.EntrySize;
        return @ptrCast(@alignCast(self.Scratch.Data + offset));
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
