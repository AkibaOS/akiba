//! AFS Journal Types

const constants = @import("../constants/constants.zig");

pub const JournalInfoCell = extern struct {
    flags: u32 = 0,
    device_signature: [32]u32 = [_]u32{0} ** 32,
    offset: u64 = 0,
    size: u64 = 0,
    reserved: [128]u8 = [_]u8{0} ** 128,
};

pub const JournalHeader = extern struct {
    magic: u32 = constants.journal_signature,
    endian: u32 = 0x12345678,
    start: u64 = 0,
    end: u64 = 0,
    size: u64 = 0,
    cell_size: u32 = constants.default_cell_size,
    checksum_type: u32 = 0,
    checksum: u32 = 0,
    sequence: u64 = 0,
};

pub const JournalCellList = extern struct {
    max_cells: u16 = 0,
    cell_count: u16 = 0,
    reserved: u32 = 0,
    cells: [1]JournalCellInfo = undefined,
};

pub const JournalCellInfo = extern struct {
    cell_number: u64 = 0,
    cell_size: u64 = 0,
};
