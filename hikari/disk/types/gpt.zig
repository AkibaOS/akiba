//! Hikari GPT Types

const constants = @import("hikari").disk.constants;
const efi = @import("hikari").efi;

pub const Header = extern struct {
    Signature: u64,
    Revision: u32,
    HeaderSize: u32,
    HeaderCRC32: u32,
    Reserved: u32,
    CurrentLBA: u64,
    BackupLBA: u64,
    FirstUsableLBA: u64,
    LastUsableLBA: u64,
    DiskGUID: efi.types.base.GUID,
    PartitionEntriesLBA: u64,
    PartitionEntriesCount: u32,
    PartitionEntrySize: u32,
    PartitionEntriesCRC32: u32,
};

pub const PartitionEntry = extern struct {
    PartitionTypeGUID: efi.types.base.GUID,
    UniquePartitionGUID: efi.types.base.GUID,
    StartingLBA: u64,
    EndingLBA: u64,
    Attributes: PartitionAttributes,
    PartitionIdentity: [constants.gpt.PARTITION_IDENTITY_LENGTH]u16,

    pub fn isEmpty(self: *const PartitionEntry) bool {
        return self.PartitionTypeGUID.TimeLow == 0 and
            self.PartitionTypeGUID.TimeMid == 0 and
            self.PartitionTypeGUID.TimeHighAndVersion == 0 and
            @as(u64, @bitCast(self.PartitionTypeGUID.ClockSequenceAndNode)) == 0;
    }

    pub fn isType(self: *const PartitionEntry, type_guid: efi.types.base.GUID) bool {
        return self.PartitionTypeGUID.equals(type_guid);
    }

    pub fn sizeInBlocks(self: *const PartitionEntry) u64 {
        if (self.EndingLBA < self.StartingLBA) {
            return 0;
        }
        return self.EndingLBA - self.StartingLBA + 1;
    }

    pub fn sizeInBytes(self: *const PartitionEntry, block_size: u32) u64 {
        return self.sizeInBlocks() * block_size;
    }
};

pub const PartitionAttributes = packed struct(u64) {
    RequiredForPlatform: bool,
    EfiFirmwareIgnore: bool,
    LegacyBiosBootable: bool,
    ReservedBits: u45,
    GuidSpecificBits: u16,
};

pub const ProtectiveMbr = extern struct {
    BootstrapCode: [440]u8,
    DiskSignature: u32,
    Reserved: u16,
    Partitions: [4]MbrPartitionRecord,
    BootSignature: u16,
};

pub const MbrPartitionRecord = extern struct {
    BootIndicator: u8,
    StartingCHS: [3]u8,
    OSType: u8,
    EndingCHS: [3]u8,
    StartingLBA: u32,
    SizeInLBA: u32,
};
