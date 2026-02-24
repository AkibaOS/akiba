//! Hikari GPT Types

const efi = @import("../../efi/efi.zig");
const constants = @import("constants.zig");

pub const Header = extern struct {
    signature: u64,
    revision: u32,
    header_size: u32,
    header_crc32: u32,
    reserved: u32,
    current_lba: u64,
    backup_lba: u64,
    first_usable_lba: u64,
    last_usable_lba: u64,
    disk_guid: efi.types.Guid,
    partition_entries_lba: u64,
    partition_entries_count: u32,
    partition_entry_size: u32,
    partition_entries_crc32: u32,
};

pub const PartitionEntry = extern struct {
    partition_type_guid: efi.types.Guid,
    unique_partition_guid: efi.types.Guid,
    starting_lba: u64,
    ending_lba: u64,
    attributes: PartitionAttributes,
    partition_identity: [constants.partition_identity_length]u16,

    pub fn is_empty(self: *const PartitionEntry) bool {
        return self.partition_type_guid.time_low == 0 and
            self.partition_type_guid.time_mid == 0 and
            self.partition_type_guid.time_high_and_version == 0 and
            @as(u64, @bitCast(self.partition_type_guid.clock_sequence_and_node)) == 0;
    }

    pub fn is_type(self: *const PartitionEntry, type_guid: efi.types.Guid) bool {
        return self.partition_type_guid.equals(type_guid);
    }

    pub fn size_in_blocks(self: *const PartitionEntry) u64 {
        if (self.ending_lba < self.starting_lba) {
            return 0;
        }
        return self.ending_lba - self.starting_lba + 1;
    }

    pub fn size_in_bytes(self: *const PartitionEntry, block_size: u32) u64 {
        return self.size_in_blocks() * block_size;
    }
};

pub const PartitionAttributes = packed struct(u64) {
    required_for_platform: bool,
    efi_firmware_ignore: bool,
    legacy_bios_bootable: bool,
    reserved_bits_3_47: u45,
    guid_specific_bits_48_63: u16,
};

pub const ProtectiveMbr = extern struct {
    bootstrap_code: [440]u8,
    disk_signature: u32,
    reserved: u16,
    partitions: [4]MbrPartitionRecord,
    boot_signature: u16,
};

pub const MbrPartitionRecord = extern struct {
    boot_indicator: u8,
    starting_chs: [3]u8,
    os_type: u8,
    ending_chs: [3]u8,
    starting_lba: u32,
    size_in_lba: u32,
};
