//! Hikari Guest Regression Fixtures

const elf = @import("hikari").loader.types.elf;

pub const ELF_HEADER_BYTES: usize = 64;
pub const ELF_PROGRAM_BYTES: usize = 56;
pub const ELF_PROGRAM_COUNT: usize = 7;
pub const ELF_TABLE_OFFSET: usize = 64;
pub const ELF_TABLE_END: usize = 456;
pub const ELF_TEXT_OFFSET: usize = 0x1000;
pub const ELF_BYTES: usize = 0x3010;
pub const ELF_PHYSICAL_BASE: u64 = 0x100000;
pub const ELF_VIRTUAL_BASE: u64 = 0xffffffff80100000;
pub const ELF_ENTRY: u64 = 0xffffffff80100010;
pub const ELF_MEMORY_BYTES: u64 = 0x17000;
pub const ELF_PAGE_BYTES: u64 = 0x1000;

pub const ELF_HEADER = [_]u8{
    0x7f, 'E', 'L',  'F',  2,    1,    1,    0,
    0,    0,   0,    0,    0,    0,    0,    0,
    2,    0,   62,   0,    1,    0,    0,    0,
    0x10, 0,   0x10, 0x80, 0xff, 0xff, 0xff, 0xff,
    0x40, 0,   0,    0,    0,    0,    0,    0,
    0,    0,   0,    0,    0,    0,    0,    0,
    0,    0,   0,    0,    64,   0,    56,   0,
    7,    0,   0,    0,    0,    0,    0,    0,
};

pub const ELF_TEXT_HEADER = [_]u8{
    1, 0,    0,    0,    5,    0,    0,    0,
    0, 0x10, 0,    0,    0,    0,    0,    0,
    0, 0,    0x10, 0x80, 0xff, 0xff, 0xff, 0xff,
    0, 0,    0x10, 0,    0,    0,    0,    0,
    0, 0x10, 0,    0,    0,    0,    0,    0,
    0, 0x10, 0,    0,    0,    0,    0,    0,
    0, 0x10, 0,    0,    0,    0,    0,    0,
};

pub const ELF_READ_ONLY_HEADER = [_]u8{
    1, 0,    0,    0,    4,    0,    0,    0,
    0, 0x20, 0,    0,    0,    0,    0,    0,
    0, 0x10, 0x10, 0x80, 0xff, 0xff, 0xff, 0xff,
    0, 0x10, 0x10, 0,    0,    0,    0,    0,
    0, 0x10, 0,    0,    0,    0,    0,    0,
    0, 0x10, 0,    0,    0,    0,    0,    0,
    0, 0x10, 0,    0,    0,    0,    0,    0,
};

pub const ELF_DATA_HEADER = [_]u8{
    1,    0,    0,    0,    6,    0,    0,    0,
    0,    0x30, 0,    0,    0,    0,    0,    0,
    0,    0x20, 0x10, 0x80, 0xff, 0xff, 0xff, 0xff,
    0,    0x20, 0x10, 0,    0,    0,    0,    0,
    0x10, 0,    0,    0,    0,    0,    0,    0,
    0,    0x10, 0,    0,    0,    0,    0,    0,
    0,    0x10, 0,    0,    0,    0,    0,    0,
};

pub const ELF_FIRST_STACK_HEADER = [_]u8{
    1, 0,    0,    0,    6,    0,    0,    0,
    0, 0,    0,    0,    0,    0,    0,    0,
    0, 0x40, 0x10, 0x80, 0xff, 0xff, 0xff, 0xff,
    0, 0x40, 0x10, 0,    0,    0,    0,    0,
    0, 0,    0,    0,    0,    0,    0,    0,
    0, 0x40, 0,    0,    0,    0,    0,    0,
    0, 0x10, 0,    0,    0,    0,    0,    0,
};

pub const ELF_SECOND_STACK_HEADER = [_]u8{
    1, 0,    0,    0,    6,    0,    0,    0,
    0, 0,    0,    0,    0,    0,    0,    0,
    0, 0x90, 0x10, 0x80, 0xff, 0xff, 0xff, 0xff,
    0, 0x90, 0x10, 0,    0,    0,    0,    0,
    0, 0,    0,    0,    0,    0,    0,    0,
    0, 0x40, 0,    0,    0,    0,    0,    0,
    0, 0x10, 0,    0,    0,    0,    0,    0,
};

pub const ELF_THIRD_STACK_HEADER = [_]u8{
    1, 0,    0,    0,    6,    0,    0,    0,
    0, 0,    0,    0,    0,    0,    0,    0,
    0, 0xe0, 0x10, 0x80, 0xff, 0xff, 0xff, 0xff,
    0, 0xe0, 0x10, 0,    0,    0,    0,    0,
    0, 0,    0,    0,    0,    0,    0,    0,
    0, 0x40, 0,    0,    0,    0,    0,    0,
    0, 0x10, 0,    0,    0,    0,    0,    0,
};

pub const ELF_FOURTH_STACK_HEADER = [_]u8{
    1, 0,    0,    0,    6,    0,    0,    0,
    0, 0,    0,    0,    0,    0,    0,    0,
    0, 0x30, 0x11, 0x80, 0xff, 0xff, 0xff, 0xff,
    0, 0x30, 0x11, 0,    0,    0,    0,    0,
    0, 0,    0,    0,    0,    0,    0,    0,
    0, 0x40, 0,    0,    0,    0,    0,    0,
    0, 0x10, 0,    0,    0,    0,    0,    0,
};

pub const VALID_ELF = ELF_HEADER ++ ELF_TEXT_HEADER ++ ELF_READ_ONLY_HEADER ++ ELF_DATA_HEADER ++ ELF_FIRST_STACK_HEADER ++ ELF_SECOND_STACK_HEADER ++ ELF_THIRD_STACK_HEADER ++ ELF_FOURTH_STACK_HEADER ++ [_]u8{0} ** (ELF_TEXT_OFFSET - ELF_TABLE_END) ++ [_]u8{0x90} ** 0x1000 ++ [_]u8{0x5a} ** 0x1000 ++ [_]u8{0x3c} ** 0x10;

pub const EXPECTED_SEGMENTS = [_]elf.Elf64ProgramHeader{
    .{ .SegmentType = 1, .Flags = 5, .Offset = 0x1000, .VirtualAddress = 0xffffffff80100000, .PhysicalAddress = 0x100000, .UnitSize = 0x1000, .MemorySize = 0x1000, .Alignment = 0x1000 },
    .{ .SegmentType = 1, .Flags = 4, .Offset = 0x2000, .VirtualAddress = 0xffffffff80101000, .PhysicalAddress = 0x101000, .UnitSize = 0x1000, .MemorySize = 0x1000, .Alignment = 0x1000 },
    .{ .SegmentType = 1, .Flags = 6, .Offset = 0x3000, .VirtualAddress = 0xffffffff80102000, .PhysicalAddress = 0x102000, .UnitSize = 0x10, .MemorySize = 0x1000, .Alignment = 0x1000 },
    .{ .SegmentType = 1, .Flags = 6, .Offset = 0, .VirtualAddress = 0xffffffff80104000, .PhysicalAddress = 0x104000, .UnitSize = 0, .MemorySize = 0x4000, .Alignment = 0x1000 },
    .{ .SegmentType = 1, .Flags = 6, .Offset = 0, .VirtualAddress = 0xffffffff80109000, .PhysicalAddress = 0x109000, .UnitSize = 0, .MemorySize = 0x4000, .Alignment = 0x1000 },
    .{ .SegmentType = 1, .Flags = 6, .Offset = 0, .VirtualAddress = 0xffffffff8010e000, .PhysicalAddress = 0x10e000, .UnitSize = 0, .MemorySize = 0x4000, .Alignment = 0x1000 },
    .{ .SegmentType = 1, .Flags = 6, .Offset = 0, .VirtualAddress = 0xffffffff80113000, .PhysicalAddress = 0x113000, .UnitSize = 0, .MemorySize = 0x4000, .Alignment = 0x1000 },
};

pub const POOL_BYTES: usize = 256;
pub const POOL_ALIGNMENT: u32 = 64;
pub const POOL_OFFSET: usize = 8;
pub const BUFFER_BYTES: usize = 23;
pub const BUFFER_OFFSET: usize = 64;
pub const ALLOCATION_BYTES: usize = 86;
pub const POOL_GUARD: u8 = 0xa5;
pub const BUFFER_VALUE: u8 = 0x3c;
