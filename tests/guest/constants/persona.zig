//! Persona Invocation State Probe Inputs

const floating = @import("tests").guest.constants.context;
const locations = @import("tests").guest.constants.postman.transport;
const types = @import("tests").guest.types.persona;

pub const DATA_ADDRESS: u64 = locations.DATA_BASE;
pub const QUERY_SERVICE: u64 = 0;
pub const YIELD_SERVICE: u64 = 1;
pub const ALLOWED_FLAGS: u64 = 0xed7;
pub const CHECKED_FLAGS: u64 = 0x603;
pub const QUERY_FLAGS: u64 = 0x603;
pub const YIELD_FLAGS: u64 = 0x602;
pub const SEEDS = [_]types.Snapshot{
    .{
        .Registers = .{
            .RBX = 0x1122334455667788,
            .RBP = 0x8877665544332211,
            .RCX = 0x1020304050607080,
            .RSI = 0x8070605040302010,
            .R8 = 0x123456789abcdef0,
            .R9 = 0x0fedcba987654321,
            .R10 = 0x55aa33cc0ff09669,
            .R11 = 0xa55ac33cf00f6996,
            .R12 = 0x3141592653589793,
            .R13 = 0x2718281828459045,
            .R14 = 0x0123456789abcdef,
            .R15 = 0xfedcba9876543210,
        },
        .Float = floating.FLOATING_SEEDS[0],
    },
    .{
        .Registers = .{
            .RBX = 0xeeddccbbaa998877,
            .RBP = 0x778899aabbccddee,
            .RCX = 0x8090a0b0c0d0e0f0,
            .RSI = 0xf0e0d0c0b0a09080,
            .R8 = 0xfedcba9876543210,
            .R9 = 0xf0123456789abcde,
            .R10 = 0xaa55cc33f00f6996,
            .R11 = 0x5aa53cc30ff09669,
            .R12 = 0x1357924680135792,
            .R13 = 0x2468013579246801,
            .R14 = 0xfedcba9876543210,
            .R15 = 0x0123456789abcdef,
        },
        .Float = floating.FLOATING_SEEDS[1],
    },
};
