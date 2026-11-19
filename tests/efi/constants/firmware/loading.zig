//! Firmware ELF Loading Regression Inputs

const types = @import("tests").efi.types.firmware.loading;

pub const ASSERTION_COUNT: usize = 8;
pub const REQUEST_CAPACITY: usize = 2;
pub const PHYSICAL_LIMIT: u64 = 0x100000000;
pub const PREFERRED_ADDRESS: u64 = 0x100000;
pub const PAGE_BYTES: usize = 0x1000;
pub const IMAGE_BYTES: usize = 0x17000;
pub const IMAGE_PAGES: usize = 23;
pub const ENTRY_POINT: u64 = 0xffffffff80100010;
pub const VIRTUAL_BASE: u64 = 0xffffffff80100000;
pub const TEXT_END: usize = 0x1000;
pub const READ_ONLY_END: usize = 0x2000;
pub const DATA_END: usize = 0x2010;
pub const DATA_MEMORY_END: usize = 0x3000;
pub const TEXT_BYTE: u8 = 0x90;
pub const READ_ONLY_BYTE: u8 = 0x5a;
pub const DATA_BYTE: u8 = 0x3c;
pub const DIRTY_BYTE: u8 = 0xa7;
pub const LARGE_UNIT_BYTES: usize = 64 * 1024 * 1024 + PAGE_BYTES;
pub const LARGE_BSS_BYTES: usize = 256 * 1024 * 1024;
pub const DATA_SEGMENT_INDEX: usize = 2;
pub const FIRST_STACK_INDEX: usize = 3;

pub const SEGMENTS = [_]types.SegmentExpectation{
    .{ .PhysicalOffset = 0x00000, .VirtualAddress = 0xffffffff80100000, .MemorySize = 0x1000, .Flags = 5 },
    .{ .PhysicalOffset = 0x01000, .VirtualAddress = 0xffffffff80101000, .MemorySize = 0x1000, .Flags = 4 },
    .{ .PhysicalOffset = 0x02000, .VirtualAddress = 0xffffffff80102000, .MemorySize = 0x1000, .Flags = 6 },
    .{ .PhysicalOffset = 0x04000, .VirtualAddress = 0xffffffff80104000, .MemorySize = 0x4000, .Flags = 6 },
    .{ .PhysicalOffset = 0x09000, .VirtualAddress = 0xffffffff80109000, .MemorySize = 0x4000, .Flags = 6 },
    .{ .PhysicalOffset = 0x0e000, .VirtualAddress = 0xffffffff8010e000, .MemorySize = 0x4000, .Flags = 6 },
    .{ .PhysicalOffset = 0x13000, .VirtualAddress = 0xffffffff80113000, .MemorySize = 0x4000, .Flags = 6 },
};
