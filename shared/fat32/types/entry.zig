//! FAT32 Entry Types (Stack/Unit entries)

const constants = @import("../constants/constants.zig");

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
        return (self.attributes & constants.attr_long_identity_mask) == constants.attr_long_identity;
    }

    pub fn is_stack(self: *const StackEntry) bool {
        return (self.attributes & constants.attr_stack) != 0;
    }

    pub fn is_volume_id(self: *const StackEntry) bool {
        return (self.attributes & constants.attr_volume_id) != 0;
    }

    pub fn get_first_cluster(self: *const StackEntry) u32 {
        return (@as(u32, self.first_cluster_high) << 16) | self.first_cluster_low;
    }

    pub fn set_first_cluster(self: *StackEntry, cluster: u32) void {
        self.first_cluster_high = @intCast((cluster >> 16) & 0xFFFF);
        self.first_cluster_low = @intCast(cluster & 0xFFFF);
    }

    pub fn get_short_identity(self: *const StackEntry, buffer: *[12]u8) usize {
        var length: usize = 0;

        var first_byte = self.identity[0];
        if (first_byte == constants.entry_kanji_lead) {
            first_byte = constants.entry_free;
        }

        var i: usize = 0;
        while (i < 8 and self.identity[i] != ' ') : (i += 1) {
            if (i == 0) {
                buffer[length] = first_byte;
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
    sequence: u8,
    identity_1: [10]u8,
    attributes: u8,
    entry_type: u8,
    checksum: u8,
    identity_2: [12]u8,
    first_cluster: u16 align(1),
    identity_3: [4]u8,

    pub fn is_last(self: *const LongIdentityEntry) bool {
        return (self.sequence & constants.lfn_last_entry) != 0;
    }

    pub fn get_sequence(self: *const LongIdentityEntry) u8 {
        return self.sequence & constants.lfn_sequence_mask;
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

pub const DirEntry = StackEntry;
pub const LongNameEntry = LongIdentityEntry;
