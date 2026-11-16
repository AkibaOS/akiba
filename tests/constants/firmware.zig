//! Firmware Handoff Regression Inputs

const status = @import("hikari").efi.constants.status;
const types = @import("tests").types.firmware;

pub const ASSERTION_COUNT: usize = 15;
pub const SERIAL_POLL_LIMIT: usize = 1000000;
pub const NEWLINE_BYTE: u8 = 10;
pub const CARRIAGE_RETURN_BYTE: u8 = 13;
pub const PHYSICAL_LIMIT: u64 = 0x100000000;
pub const PAGE_BYTES: usize = 4096;
pub const STACK_PAGES: usize = 16;
pub const PARAMS_PAGES: usize = 1;
pub const LEDGER_CAPACITY: usize = 4;
pub const TRACE_CAPACITY: usize = 16;
pub const SCRIPT_CAPACITY: usize = 8;
pub const DESCRIPTOR_BYTES: usize = 48;
pub const DESCRIPTOR_VERSION: u32 = 1;
pub const MAP_BYTES: usize = 96;
pub const MAP_ENTRIES: u32 = 2;
pub const GROWN_MAP_BYTES: usize = 4144;
pub const FIRST_KEY: usize = 41;
pub const SECOND_KEY: usize = 42;
pub const LAST_KEY: usize = 47;
pub const RETRY_MAP_CALLS: usize = 8;
pub const RETRY_EXIT_CALLS: usize = 7;

pub const GROWTH_MAPS = [_]types.MapReply{
    .{ .Status = status.BUFFER_TOO_SMALL },
    .{ .Status = status.BUFFER_TOO_SMALL, .Size = GROWN_MAP_BYTES },
    .{ .Status = status.SUCCESS },
};
pub const BAD_STRIDE_MAPS = [_]types.MapReply{
    .{ .Status = status.BUFFER_TOO_SMALL },
    .{ .Status = status.SUCCESS, .DescriptorSize = 39 },
};
pub const BAD_VERSION_MAPS = [_]types.MapReply{
    .{ .Status = status.BUFFER_TOO_SMALL },
    .{ .Status = status.SUCCESS, .DescriptorVersion = 2 },
};
pub const STALE_MAPS = [_]types.MapReply{
    .{ .Status = status.BUFFER_TOO_SMALL },
    .{ .Status = status.SUCCESS, .Key = FIRST_KEY },
    .{ .Status = status.SUCCESS, .Key = SECOND_KEY },
};
pub const BOUNDED_MAPS = [_]types.MapReply{
    .{ .Status = status.BUFFER_TOO_SMALL },
    .{ .Status = status.SUCCESS, .Key = 41 },
    .{ .Status = status.SUCCESS, .Key = 42 },
    .{ .Status = status.SUCCESS, .Key = 43 },
    .{ .Status = status.SUCCESS, .Key = 44 },
    .{ .Status = status.SUCCESS, .Key = 45 },
    .{ .Status = status.SUCCESS, .Key = 46 },
    .{ .Status = status.SUCCESS, .Key = 47 },
};
pub const ROLLBACK_MAPS = [_]types.MapReply{
    .{ .Status = status.BUFFER_TOO_SMALL },
    .{ .Status = status.BUFFER_TOO_SMALL, .Size = GROWN_MAP_BYTES },
};
pub const SUCCESS_EXIT = [_]usize{status.SUCCESS};
pub const STALE_EXITS = [_]usize{ status.INVALID_PARAMETER, status.SUCCESS };
pub const BOUNDED_EXITS = [_]usize{status.INVALID_PARAMETER} ** RETRY_EXIT_CALLS;
