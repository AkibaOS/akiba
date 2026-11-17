//! Independent Compiler Fixture Byte Patterns

const sections = @import("fixture").strings.sections;
const values = @import("fixture").constants.values;

pub const DATA_PATTERN = [_]u8{ 0x17, 0x92, 0x4d, 0xe3, 0x6a, 0xb5, 0x08 };
pub const DATA_BYTES = DATA_PATTERN ** values.DATA_REPETITIONS;
pub const RODATA_PATTERN = [_]u8{ 0xc1, 0x2e, 0x73, 0x04, 0x9b, 0x56, 0xed, 0x38, 0x85, 0xfa, 0x6f };
pub export const akiba_fixture_rodata: [RODATA_PATTERN.len * values.RODATA_REPETITIONS]u8 align(values.PAGE_SIZE) linksection(sections.RODATA) = RODATA_PATTERN ** values.RODATA_REPETITIONS;
