//! Native Thread Context Check Values

const fixtures = @import("tests").guest.types.context;

pub const YIELD_ROUNDS: u32 = 3;
pub const PREEMPTION_BUDGET: u64 = 100000000;
pub const INTERRUPT_ENABLE: u64 = 0x200;
pub const DIRECTION_FLAG: u64 = 0x400;
pub const RESERVED_FLAG: u64 = 0x2;
pub const PAGE_FRAME_MASK: u64 = 0x000ffffffffff000;
pub const STACK_ALIGNMENT: u64 = 16;
pub const COOPERATIVE_FRAME_SIZE: usize = 24;
pub const FPU_FRAME_SIZE: usize = 520;
pub const ARMED_STAGE: u32 = 1;
pub const PROGRESSED_STAGE: u32 = 2;

pub const STACK_CANARIES = [_]u64{ 0x0123456789abcdef, 0xfedcba9876543210, 0x55aa55aa55aa55aa, 0xaa55aa55aa55aa55 };

pub const REGISTER_SEEDS = [_]fixtures.Registers{
    .{
        .RBX = 0x1122334455667788,
        .RBP = 0x8877665544332211,
        .R12 = 0x123456789abcdef0,
        .R13 = 0x0fedcba987654321,
        .R14 = 0x55aa33cc0ff09669,
        .R15 = 0xa55ac33cf00f6996,
    },
    .{
        .RBX = 0xeeddccbbaa998877,
        .RBP = 0x778899aabbccddee,
        .R12 = 0xfedcba9876543210,
        .R13 = 0xf0123456789abcde,
        .R14 = 0xaa55cc33f00f6996,
        .R15 = 0x5aa53cc30ff09669,
    },
};

pub const FLOATING_SEEDS = [_]fixtures.Floating{
    .{
        .X87 = .{ 0x3ff4000000000000, 0xc01a000000000000 },
        .XMM0 = .{ 0x0123456789abcdef, 0xfedcba9876543210 },
        .XMM15 = .{ 0x1020304050607080, 0x8070605040302010 },
        .MXCSR = 0x3f80,
        .Control = 0x077f,
    },
    .{
        .X87 = .{ 0x400c000000000000, 0xbfe0000000000000 },
        .XMM0 = .{ 0xfedcba9876543210, 0x0123456789abcdef },
        .XMM15 = .{ 0x0f1e2d3c4b5a6978, 0x8796a5b4c3d2e1f0 },
        .MXCSR = 0x5f80,
        .Control = 0x0b7f,
    },
};
