//! Volatile Compiler Fixture Validation

const invocation = @import("fixtureasm").invocation;
const memory = @import("fixture").memory;
const payload = @import("fixture").constants.payload;
const startup = @import("fixture").strings.startup;
const values = @import("fixture").constants.values;

pub fn run(argument: u64) noreturn {
    if (!startupMatches(argument)) invocation.exit(values.BAD_ARGUMENT);
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

fn startupMatches(argument: u64) bool {
    const field_bytes = @sizeOf(u64);
    const identity = values.STARTUP_FIELDS * field_bytes;
    const parameters = identity + startup.IDENTITY.len;
    const length = parameters + values.STARTUP_PARAMETER_BYTES;
    if (argument < values.PAGE_SIZE or argument > values.USER_LAST + 1 - length or argument % values.PAGE_SIZE != 0) return false;
    const bytes: [*]const volatile u8 = @ptrFromInt(argument);
    if (word(bytes, 0) != values.STARTUP_VERSION or word(bytes, field_bytes) != startup.IDENTITY.len or
        word(bytes, 2 * field_bytes) != values.STARTUP_PARAMETER_BYTES) return false;
    for (startup.IDENTITY, 0..) |expected, index| if (bytes[identity + index] != expected) return false;
    for (0..values.STARTUP_PARAMETER_BYTES) |index| {
        const expected = @as(u8, @truncate(index)) ^ @as(u8, @truncate(index >> @bitSizeOf(u8))) ^ values.STARTUP_PARAMETER_MASK;
        if (bytes[parameters + index] != expected) return false;
    }
    return true;
}

fn word(bytes: [*]const volatile u8, offset: usize) u64 {
    var value: u64 = 0;
    for (0..@sizeOf(u64)) |index| value |= @as(u64, bytes[offset + index]) << @intCast(index * @bitSizeOf(u8));
    return value;
}

fn writableByte(index: usize) u8 {
    return @as(u8, @truncate(index)) ^ @as(u8, @truncate(index >> values.BSS_SHIFT)) ^ values.BSS_MASK;
}

pub fn panic() noreturn {
    invocation.exit(values.BAD_PANIC);
}
