//! Independently Encoded Test GPT Buffers

const layout = @import("tests").fast.constants.gpt.layout;

pub const Disk = struct {
    Primary: [layout.BLOCK_BYTES]u8 = @splat(0),
    Table: [layout.BLOCK_BYTES]u8 = @splat(0),
};
