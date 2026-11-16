//! Storage Regression Types

const constants = @import("tests").constants.storage;

pub const Transfer = struct {
    Cell: u64,
    Length: usize,
};

pub const ByteDevice = struct {
    Bytes: [constants.DEVICE_BYTES]u8 = [_]u8{constants.SCRATCH_BYTE} ** constants.DEVICE_BYTES,
    Reads: [constants.TRANSFER_CAPACITY]Transfer = undefined,
    Writes: [constants.TRANSFER_CAPACITY]Transfer = undefined,
    ReadCount: usize = 0,
    WriteCount: usize = 0,
    FailureCell: ?u64 = null,
};
