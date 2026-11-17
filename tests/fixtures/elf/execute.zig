//! Volatile Compiler Fixture Validation

const invocation = @import("fixtureasm").invocation;
const memory = @import("fixture").memory;
const payload = @import("fixture").constants.payload;
const values = @import("fixture").constants.values;

pub fn run(argument: u64) noreturn {
    if (argument != values.OPAQUE_ARGUMENT) invocation.exit(values.BAD_ARGUMENT);
    const initialized: *volatile [payload.DATA_BYTES.len]u8 = &memory.akiba_fixture_data;
    const readonly: *const volatile [payload.akiba_fixture_rodata.len]u8 = &payload.akiba_fixture_rodata;
    const zeroed: *volatile [values.BSS_LENGTH]u8 = &memory.akiba_fixture_bss;
    for (0..initialized.len) |index| {
        if (initialized[index] != payload.DATA_PATTERN[index % payload.DATA_PATTERN.len]) invocation.exit(values.BAD_DATA);
    }
    for (0..readonly.len) |index| {
        if (readonly[index] != payload.RODATA_PATTERN[index % payload.RODATA_PATTERN.len]) invocation.exit(values.BAD_RODATA);
    }
    for (0..zeroed.len) |index| {
        if (zeroed[index] != 0) invocation.exit(values.BAD_BSS_ZERO);
    }
    for (0..zeroed.len) |index| {
        zeroed[index] = writableByte(index);
    }
    for (0..zeroed.len) |index| {
        if (zeroed[index] != writableByte(index)) invocation.exit(values.BAD_BSS_WRITE);
    }
    invocation.exit(values.SUCCESS);
}

fn writableByte(index: usize) u8 {
    return @as(u8, @truncate(index)) ^ @as(u8, @truncate(index >> values.BSS_SHIFT)) ^ values.BSS_MASK;
}

pub fn panic() noreturn {
    invocation.exit(values.BAD_PANIC);
}
