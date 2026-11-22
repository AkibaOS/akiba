//! Pointer Free GPT Volume Identity

const std = @import("std");

const constants = @import("sdk").storage.constants.volume;

pub const Volume = extern struct {
    DiskGUID: [constants.GUID_BYTES]u8,
    PartitionGUID: [constants.GUID_BYTES]u8,
    FirstLBA: u64,
    LastLBA: u64,
    DiskLastLBA: u64,
    BlockBytes: u32,
    Reserved: u32 = 0,

    pub fn isValid(self: Volume) bool {
        return !std.mem.allEqual(u8, &self.DiskGUID, 0) and
            !std.mem.allEqual(u8, &self.PartitionGUID, 0) and
            self.FirstLBA != 0 and self.FirstLBA <= self.LastLBA and self.LastLBA < self.DiskLastLBA and
            self.BlockBytes >= constants.MINIMUM_BLOCK_BYTES and std.math.isPowerOfTwo(self.BlockBytes) and self.Reserved == 0;
    }
};
