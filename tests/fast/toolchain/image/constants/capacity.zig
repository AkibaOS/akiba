//! Independent AFS Capacity Planning Expectations

const tool = @import("mkafsdisk");
const strings = @import("tests").fast.toolchain.image.strings.capacity;
const types = @import("tests").fast.toolchain.image.types.capacity;

pub const CELL_BYTES: usize = 4096;
pub const DESCRIPTOR_BYTES: usize = 16;
pub const OFFSET_BYTES: usize = 2;
pub const HEADER_NODE: u32 = 0;
pub const FIRST_LEAF: u32 = 1;
pub const EMPTY_TREE_NODES: u32 = 2;
pub const MAP_START: u32 = 2;
pub const PAYLOAD_CELLS: u64 = 3;
pub const EXACT_VOLUME_CELLS: u64 = 6;
pub const SHORT_VOLUME_CELLS: u64 = 5;
pub const ONE_PAYLOAD_CELL: u64 = 1;
pub const SPAN_TOTAL_CELLS: u64 = 20;
pub const SPAN_DATA_START: u64 = 5;
pub const SPAN_SECOND_START: u64 = 6;
pub const SPAN_FINAL_END: u64 = 8;
pub const MAXIMUM_U32: u64 = 4294967295;
pub const UNREPRESENTABLE_U32: u64 = 4294967296;
pub const BELOW_MINIMUM_MIB: u32 = 35;
pub const MINIMUM_MIB: u32 = 36;
pub const MAXIMUM_MIB: u32 = 16777251;
pub const EXCESSIVE_MIB: u32 = 16777252;
pub const DEFAULT_MIB: u32 = 64;
pub const DEFAULT_BYTES: u64 = 67108864;
pub const DEFAULT_SECTORS: u64 = 131072;
pub const ESP_FIRST: u64 = 2048;
pub const ESP_LAST: u64 = 71679;
pub const AFS_FIRST: u64 = 71680;
pub const AFS_LAST: u64 = 131038;
pub const PRIMARY_HEADER: u64 = 1;
pub const PRIMARY_ENTRIES: u64 = 2;
pub const BACKUP_HEADER: u64 = 131071;
pub const BACKUP_ENTRIES: u64 = 131039;
pub const FIRST_USABLE: u64 = 34;
pub const PARTITION_START: u64 = 36700160;
pub const PARTITION_BYTES: u64 = 30391808;
pub const TRAILING_BYTES: u64 = 3584;
pub const SECTOR_BYTES: u64 = 512;
pub const GPT_TABLE_SECTORS: u64 = 32;
pub const ORIGIN_PARENT: u32 = 1;
pub const ORIGIN_ID: u32 = 2;
pub const FIRST_USER_ID: u32 = 16;
pub const LAST_ASSIGNABLE_ID: u32 = 4294967294;
pub const EXHAUSTED_ID: u32 = 4294967295;
pub const SORTED_ENTRY_INDICES = [_]usize{ 3, 2, 4, 1, 0 };
pub const KEY_PARENT: u32 = 0x11223344;
pub const KEY_NODE: u32 = 0x55667788;
pub const TIMESTAMP: u64 = 0x0102030405060708;
pub const MAXIMUM_NAME_BYTES: usize = 256;
pub const INVALID_NAME_BYTES: usize = 257;
pub const MAXIMUM_KEY_BYTES: u16 = 520;
pub const MAXIMUM_KEY_LE = [_]u8{ 0x08, 0x02 };
pub const KEY_PARENT_LE = [_]u8{ 0x44, 0x33, 0x22, 0x11 };
pub const KEY_NODE_LE = [_]u8{ 0x88, 0x77, 0x66, 0x55 };
pub const TIMESTAMP_LE = [_]u8{ 0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01 };
pub const KEY_PADDING_OFFSET: usize = 18;
pub const KEY_PARENT_OFFSET: usize = 20;
pub const KEY_IDENTITY_OFFSET: usize = 24;
pub const MAXIMUM_PAYLOAD_OFFSET: usize = 536;
pub const PAYLOAD_NODE_OFFSET: usize = 544;
pub const PAYLOAD_PADDING_OFFSET: usize = 548;
pub const PAYLOAD_TIMESTAMP_OFFSET: usize = 552;
pub const MAXIMUM_RECORD_END: usize = 936;
pub const HEADER_MAXIMUM_KEY_OFFSET: usize = 38;
pub const HEADER_TOTAL_NODES_OFFSET: usize = 40;
pub const HEADER_RECORD_COUNT_OFFSET: usize = 10;
pub const HEADER_RECORD_BYTES: u16 = 1;
pub const UNIT_TYPE_LE = [_]u8{ 2, 0 };
pub const FILL_BYTE: u8 = 0xa5;
pub const NAME_BYTE: u8 = 'x';
pub const DIGIT_ZERO: u8 = '0';
pub const DECIMAL_TENS: usize = 10;
pub const DECIMAL_HUNDREDS: usize = 100;
pub const GAP_STRIDE: usize = 2;
pub const NAME_SUFFIX_BYTES: usize = 3;
pub const EXACT_RECORD_BYTES: usize = 814;
pub const EXACT_OFFSETS = [_]u16{ 16, 830, 1644, 2458, 3272 };
pub const EXACT_RECORD_END: usize = 4086;
pub const MAXIMUM_PACKED_RECORD: usize = 4078;
pub const OVERSIZED_RECORD: usize = 4079;
pub const EXACT_LEAVES: u32 = 2;
pub const EXACT_ROOT: u32 = 3;
pub const EXACT_NODES: u32 = 4;
pub const DEEP_RECORDS: usize = 128;
pub const DEEP_LEAVES: u32 = 26;
pub const DEEP_ROOT: u32 = 30;
pub const DEEP_NODES: u32 = 31;
pub const DEEP_DEPTH: u16 = 3;
pub const FORMER_INDEX_NODES: usize = 16;
pub const TAIL_RECORDS: usize = 51;
pub const TAIL_LEAVES: usize = 11;
pub const TAIL_FIRST_PARENT: usize = 12;
pub const TAIL_LAST_PARENT: usize = 13;
pub const TAIL_NODES: usize = 15;
pub const BYTE_IDENTITY_LE = [_]u8{ 0xc3, 0x00, 0xa9, 0x00 };
pub const AFTER_LAST_SUFFIX: usize = 999;
pub const MANIFEST_ENTRIES: usize = 5;
pub const MANIFEST_UNITS: u32 = 3;
pub const MANIFEST_STACKS: u32 = 2;
pub const MANIFEST_NEXT_ID: u32 = 20;
pub const ALPHA_ID: u32 = 16;
pub const BETA_ID: u32 = 17;
pub const NESTED_ID: u32 = 18;
pub const CHILD_ID: u32 = 19;

pub const VOLUMES = [_]types.VolumeCase{
    .{ .TotalCells = 131071, .BitmapBytes = 16384, .BitmapCells = 4, .IndexStartCell = 6, .DataStartCell = 8, .UsedCells = 11, .FreeCells = 131060 },
    .{ .TotalCells = 131072, .BitmapBytes = 16384, .BitmapCells = 4, .IndexStartCell = 6, .DataStartCell = 8, .UsedCells = 11, .FreeCells = 131061 },
    .{ .TotalCells = 131073, .BitmapBytes = 16385, .BitmapCells = 5, .IndexStartCell = 7, .DataStartCell = 9, .UsedCells = 12, .FreeCells = 131061 },
};

pub const DISKS = [_]types.DiskCase{
    .{ .SizeMiB = 36, .TotalSectors = 73728, .ProtectiveSectorCount = 73727, .TotalCells = 251 },
    .{ .SizeMiB = 2097151, .TotalSectors = 4294965248, .ProtectiveSectorCount = 4294965247, .TotalCells = 536861691 },
    .{ .SizeMiB = 2097152, .TotalSectors = 4294967296, .ProtectiveSectorCount = 4294967295, .TotalCells = 536861947 },
    .{ .SizeMiB = 2097153, .TotalSectors = 4294969344, .ProtectiveSectorCount = 4294967295, .TotalCells = 536862203 },
    .{ .SizeMiB = 16777251, .TotalSectors = 34359810048, .ProtectiveSectorCount = 4294967295, .TotalCells = 4294967291 },
};

pub const ORDERED_INPUT = [_]tool.types.catalog.entry.Entry{
    .{ .ParentNodeId = 8, .NodeId = 20, .Identity = strings.FIRST_IDENTITY, .Kind = .Unit },
    .{ .ParentNodeId = 7, .NodeId = 19, .Identity = strings.LOWER_IDENTITY, .Kind = .Unit },
    .{ .ParentNodeId = 7, .NodeId = 18, .Identity = strings.PREFIX_IDENTITY, .Kind = .Unit },
    .{ .ParentNodeId = 7, .NodeId = 16, .Identity = strings.FIRST_IDENTITY, .Kind = .Unit },
    .{ .ParentNodeId = 7, .NodeId = 17, .Identity = strings.SECOND_IDENTITY, .Kind = .Unit },
};
