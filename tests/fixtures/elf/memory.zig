//! Compiler Fixture Writable Storage

const payload = @import("fixture").constants.payload;
const sections = @import("fixture").strings.sections;
const values = @import("fixture").constants.values;

pub export var akiba_fixture_data: [payload.DATA_BYTES.len]u8 align(values.PAGE_SIZE) linksection(sections.DATA) = payload.DATA_BYTES;
pub export var akiba_fixture_bss: [values.BSS_LENGTH]u8 align(values.PAGE_SIZE) linksection(sections.BSS) = @splat(0);
