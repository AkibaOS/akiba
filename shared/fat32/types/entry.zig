//! FAT32 Entry Types (Stack/Unit entries)

const std = @import("std");

const constants = @import("../constants/constants.zig");

pub const StackEntry = extern struct {
    Identity: [8]u8,
    Extension: [3]u8,
    Attributes: u8,
    ReservedNt: u8,
    CreationTimeTenths: u8,
    CreationTime: u16 align(1),
    CreationDate: u16 align(1),
    LastAccessDate: u16 align(1),
    FirstClusterHigh: u16 align(1),
    WriteTime: u16 align(1),
    WriteDate: u16 align(1),
    FirstClusterLow: u16 align(1),
    UnitSize: u32 align(1),

    pub fn isFree(self: *const StackEntry) bool {
        return self.Identity[0] == constants.entries.ENTRY_FREE;
    }

    pub fn isEnd(self: *const StackEntry) bool {
        return self.Identity[0] == constants.entries.ENTRY_END;
    }

    pub fn isLongIdentity(self: *const StackEntry) bool {
        return (self.Attributes & constants.attributes.ATTR_LONG_IDENTITY_MASK) == constants.attributes.ATTR_LONG_IDENTITY;
    }

    pub fn isStack(self: *const StackEntry) bool {
        return (self.Attributes & constants.attributes.ATTR_STACK) != 0;
    }

    pub fn isVolumeId(self: *const StackEntry) bool {
        return (self.Attributes & constants.attributes.ATTR_VOLUME_ID) != 0;
    }

    pub fn getFirstCluster(self: *const StackEntry) u32 {
        return (@as(u32, self.FirstClusterHigh) << @bitSizeOf(u16)) | self.FirstClusterLow;
    }

    pub fn setFirstCluster(self: *StackEntry, cluster: u32) void {
        self.FirstClusterHigh = @truncate(cluster >> @bitSizeOf(u16));
        self.FirstClusterLow = @truncate(cluster);
    }

    pub fn getShortIdentity(self: *const StackEntry, buffer: *[constants.sizes.SHORT_DISPLAY_LENGTH]u8) usize {
        var length: usize = 0;

        var first_byte = self.Identity[0];
        if (first_byte == constants.entries.ENTRY_KANJI_LEAD) {
            first_byte = constants.entries.ENTRY_FREE;
        }

        var index: usize = 0;
        while (index < constants.sizes.SHORT_IDENTITY_LENGTH and self.Identity[index] != ' ') : (index += 1) {
            if (index == 0) {
                buffer[length] = first_byte;
            } else {
                buffer[length] = self.Identity[index];
            }
            length += 1;
        }

        if (self.Extension[0] != ' ') {
            buffer[length] = '.';
            length += 1;

            var ext_index: usize = 0;
            while (ext_index < constants.sizes.SHORT_EXT_LENGTH and self.Extension[ext_index] != ' ') : (ext_index += 1) {
                buffer[length] = self.Extension[ext_index];
                length += 1;
            }
        }

        return length;
    }
};

pub const LongIdentityEntry = extern struct {
    Sequence: u8,
    Identity1: [10]u8,
    Attributes: u8,
    EntryType: u8,
    Checksum: u8,
    Identity2: [12]u8,
    FirstCluster: u16 align(1),
    Identity3: [4]u8,

    pub fn isLast(self: *const LongIdentityEntry) bool {
        return (self.Sequence & constants.entries.LFN_LAST_ENTRY) != 0;
    }

    pub fn getSequence(self: *const LongIdentityEntry) u8 {
        return self.Sequence & constants.entries.LFN_SEQUENCE_MASK;
    }

    pub fn extractChars(self: *const LongIdentityEntry, buffer: *[constants.entries.LFN_CHARS_PER_ENTRY]u16) void {
        var char_index: usize = 0;

        var byte_index: usize = 0;
        while (byte_index < self.Identity1.len) : (byte_index += @sizeOf(u16)) {
            buffer[char_index] = std.mem.readInt(u16, self.Identity1[byte_index..][0..@sizeOf(u16)], .little);
            char_index += 1;
        }

        byte_index = 0;
        while (byte_index < self.Identity2.len) : (byte_index += @sizeOf(u16)) {
            buffer[char_index] = std.mem.readInt(u16, self.Identity2[byte_index..][0..@sizeOf(u16)], .little);
            char_index += 1;
        }

        byte_index = 0;
        while (byte_index < self.Identity3.len) : (byte_index += @sizeOf(u16)) {
            buffer[char_index] = std.mem.readInt(u16, self.Identity3[byte_index..][0..@sizeOf(u16)], .little);
            char_index += 1;
        }
    }
};

pub const TimeFormat = packed struct(u16) {
    SecondDiv2: u5,
    Minute: u6,
    Hour: u5,
};

pub const DateFormat = packed struct(u16) {
    Day: u5,
    Month: u4,
    YearFrom1980: u7,
};
