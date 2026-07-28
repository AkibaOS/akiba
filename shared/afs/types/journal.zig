//! AFS Journal Types

const constants = @import("shared").afs.constants;

pub const JournalInfoCell = extern struct {
    Flags: u32 = 0,
    DeviceSignature: [32]u32 = [_]u32{0} ** 32,
    Offset: u64 = 0,
    Size: u64 = 0,
    Reserved: [128]u8 = [_]u8{0} ** 128,
};

pub const JournalHeader = extern struct {
    Magic: u32 = constants.magic.JOURNAL_SIGNATURE,
    Endian: u32 = constants.magic.JOURNAL_ENDIAN_MARKER,
    Start: u64 = 0,
    End: u64 = 0,
    Size: u64 = 0,
    CellSize: u32 = constants.sizes.DEFAULT_CELL_SIZE,
    ChecksumType: u32 = 0,
    Checksum: u32 = 0,
    Sequence: u64 = 0,
};

pub const JournalCellList = extern struct {
    MaxCells: u16 = 0,
    CellCount: u16 = 0,
    Reserved: u32 = 0,
    Cells: [1]JournalCellInfo = undefined,
};

pub const JournalCellInfo = extern struct {
    CellNumber: u64 = 0,
    CellSize: u64 = 0,
};
