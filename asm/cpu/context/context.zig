//! Returning CPU Context Transfer

const std = @import("std");

const constants = @import("asm").cpu.constants.control;
const strings = @import("asm").cpu.strings.context;
const types = @import("asm").cpu.types.context;

const Context = types.Context;

pub fn transfer(previous: *Context, next: *const Context) void {
    const boundary = @extern(types.Transfer, .{ .name = strings.ENTRY_SYMBOL });
    @call(.never_tail, boundary, .{ previous, next });
}

fn instructions() []const u8 {
    comptime var offsets: []const u8 = strings.EMPTY;
    inline for (@typeInfo(Context).@"struct".fields) |field| {
        offsets = offsets ++ std.fmt.comptimePrint(strings.OFFSET_FORMAT, .{ field.name, @offsetOf(Context, field.name) });
    }
    return offsets ++ std.fmt.comptimePrint(strings.GLOBAL_FORMAT, .{
        constants.CR4_PAGE_GLOBAL_ENABLE,
        constants.RFLAGS_INTERRUPT_ENABLE,
        constants.RFLAGS_RESERVED,
    }) ++ strings.TRANSFER;
}

export fn shift_context() callconv(.naked) void {
    asm volatile (instructions() ::: .{ .memory = true });
}
