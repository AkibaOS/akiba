//! Hikari FAT32 Types

const constants = @import("constants.zig");

pub const BootSector = extern struct {
    jump_boot: [3]u8,
    oem_identity: [8]u8,
    bytes_per_sector: u16 align(1),
    sectors_per_cluster: u8,
    reserved_sector_count: u16 align(1),
    fat_count: u8,
    origin_entry_count: u16 align(1),
    total_sectors_16: u16 align(1),
    media_type: u8,
    fat_size_16: u16 align(1),
    sectors_per_track: u16 align(1),
    head_count: u16 align(1),
    hidden_sector_count: u32 align(1),
    total_sectors_32: u32 align(1),
    fat_size_32: u32 align(1),
    ext_flags: u16 align(1),
    fs_version: u16 align(1),
    origin_cluster: u32 align(1),
    fs_info_sector: u16 align(1),
    backup_boot_sector: u16 align(1),
    reserved: [12]u8,
    drive_number: u8,
    reserved1: u8,
    boot_signature: u8,
    volume_id: u32 align(1),
    volume_label: [11]u8,
    fs_type: [8]u8,
    boot_code: [420]u8,
    signature: u16 align(1),

    pub fn is_valid(self: *const BootSector) bool {
        if (self.signature != constants.boot_signature) {
            return false;
        }
        if (self.bytes_per_sector < constants.sector_size_minimum or
            self.bytes_per_sector > constants.sector_size_maximum)
        {
            return false;
        }
        if (self.sectors_per_cluster == 0) {
            return false;
        }
        if (self.fat_count == 0) {
            return false;
        }
        if (self.fat_size_32 == 0) {
            return false;
        }
        return true;
    }

    pub fn get_fat_start_sector(self: *const BootSector) u32 {
        return self.reserved_sector_count;
    }

    pub fn get_data_start_sector(self: *const BootSector) u32 {
        return self.reserved_sector_count + (self.fat_count * self.fat_size_32);
    }

    pub fn get_total_clusters(self: *const BootSector) u32 {
        const data_sectors = self.total_sectors_32 - self.get_data_start_sector();
        return data_sectors / self.sectors_per_cluster;
    }

    pub fn cluster_to_sector(self: *const BootSector, cluster: u32) u32 {
        return self.get_data_start_sector() + ((cluster - 2) * self.sectors_per_cluster);
    }
};

pub const FsInfo = extern struct {
    signature_1: u32 align(1),
    reserved_1: [480]u8,
    signature_2: u32 align(1),
    free_cluster_count: u32 align(1),
    next_free_cluster: u32 align(1),
    reserved_2: [12]u8,
    signature_3: u32 align(1),

    pub fn is_valid(self: *const FsInfo) bool {
        return self.signature_1 == constants.fs_info_signature_1 and
            self.signature_2 == constants.fs_info_signature_2 and
            self.signature_3 == constants.fs_info_signature_3;
    }
};

pub const StackEntry = extern struct {
    identity: [8]u8,
    extension: [3]u8,
    attributes: u8,
    reserved_nt: u8,
    creation_time_tenths: u8,
    creation_time: u16 align(1),
    creation_date: u16 align(1),
    last_access_date: u16 align(1),
    first_cluster_high: u16 align(1),
    write_time: u16 align(1),
    write_date: u16 align(1),
    first_cluster_low: u16 align(1),
    unit_size: u32 align(1),

    pub fn is_free(self: *const StackEntry) bool {
        return self.identity[0] == constants.entry_free;
    }

    pub fn is_end(self: *const StackEntry) bool {
        return self.identity[0] == constants.entry_end;
    }

    pub fn is_long_identity(self: *const StackEntry) bool {
        return (self.attributes & constants.attribute_long_identity_mask) == constants.attribute_long_identity;
    }

    pub fn is_stack(self: *const StackEntry) bool {
        return (self.attributes & constants.attribute_stack) != 0;
    }

    pub fn is_volume_id(self: *const StackEntry) bool {
        return (self.attributes & constants.attribute_volume_id) != 0;
    }

    pub fn get_first_cluster(self: *const StackEntry) u32 {
        return (@as(u32, self.first_cluster_high) << 16) | self.first_cluster_low;
    }

    pub fn get_short_identity(self: *const StackEntry, buffer: *[12]u8) usize {
        var length: usize = 0;

        var identity_byte = self.identity[0];
        if (identity_byte == constants.entry_kanji_lead) {
            identity_byte = constants.entry_free;
        }

        var i: usize = 0;
        while (i < 8 and self.identity[i] != ' ') : (i += 1) {
            if (i == 0) {
                buffer[length] = identity_byte;
            } else {
                buffer[length] = self.identity[i];
            }
            length += 1;
        }

        if (self.extension[0] != ' ') {
            buffer[length] = '.';
            length += 1;

            var j: usize = 0;
            while (j < 3 and self.extension[j] != ' ') : (j += 1) {
                buffer[length] = self.extension[j];
                length += 1;
            }
        }

        return length;
    }
};

pub const LongIdentityEntry = extern struct {
    sequence_number: u8,
    identity_1: [10]u8,
    attributes: u8,
    entry_type: u8,
    checksum: u8,
    identity_2: [12]u8,
    first_cluster_low: u16 align(1),
    identity_3: [4]u8,

    pub fn is_last(self: *const LongIdentityEntry) bool {
        return (self.sequence_number & constants.long_identity_last_entry) != 0;
    }

    pub fn get_sequence(self: *const LongIdentityEntry) u8 {
        return self.sequence_number & constants.long_identity_sequence_mask;
    }

    pub fn extract_chars(self: *const LongIdentityEntry, buffer: *[13]u16) void {
        var index: usize = 0;

        var i: usize = 0;
        while (i < 10) : (i += 2) {
            buffer[index] = @as(u16, self.identity_1[i]) | (@as(u16, self.identity_1[i + 1]) << 8);
            index += 1;
        }

        i = 0;
        while (i < 12) : (i += 2) {
            buffer[index] = @as(u16, self.identity_2[i]) | (@as(u16, self.identity_2[i + 1]) << 8);
            index += 1;
        }

        i = 0;
        while (i < 4) : (i += 2) {
            buffer[index] = @as(u16, self.identity_3[i]) | (@as(u16, self.identity_3[i + 1]) << 8);
            index += 1;
        }
    }
};

pub const TimeFormat = packed struct(u16) {
    second_div_2: u5,
    minute: u6,
    hour: u5,
};

pub const DateFormat = packed struct(u16) {
    day: u5,
    month: u4,
    year_from_1980: u7,
};
