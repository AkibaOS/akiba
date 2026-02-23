//! Postman invocation - Letter passing between parent and child Kata

const copy = @import("../../utils/mem/copy.zig");
const handler = @import("../handler.zig");
const heap = @import("../../memory/heap.zig");
const int = @import("../../utils/types/int.zig");
const kata_constants = @import("../../common/constants/kata.zig");
const kata_limits = @import("../../common/limits/kata.zig");
const kata_mod = @import("../../kata/kata.zig");
const memory_limits = @import("../../common/limits/memory.zig");
const result = @import("../../utils/types/result.zig");
const sensei = @import("../../kata/sensei/sensei.zig");
const slice = @import("../../utils/mem/slice.zig");

pub fn invoke(ctx: *handler.InvocationContext) void {
    switch (ctx.rdi) {
        kata_constants.POSTMAN_SEND => send_letter(ctx),
        kata_constants.POSTMAN_READ => read_letter(ctx),
        else => result.set_error(ctx),
    }
}

fn send_letter(ctx: *handler.InvocationContext) void {
    const letter_type = int.u8_of(ctx.rsi);
    const data_ptr = ctx.rdx;
    const data_len = int.u16_of(ctx.r10);

    if (data_len > kata_limits.MAX_LETTER_LENGTH) return result.set_error(ctx);
    if (data_len > 0 and !memory_limits.is_valid_kata_pointer(data_ptr)) return result.set_error(ctx);

    const sender = sensei.get_current_kata() orelse return result.set_error(ctx);
    const parent = kata_mod.get_kata(sender.parent_id) orelse return result.set_error(ctx);

    parent.letter_type = letter_type;
    parent.letter_len = data_len;

    if (data_len > 0) {
        if (parent.letter_capacity < data_len) {
            if (parent.letter_data) |old| {
                heap.free(@ptrCast(old), parent.letter_capacity);
            }
            const new_buf = heap.alloc(data_len) orelse return result.set_error(ctx);
            parent.letter_data = new_buf;
            parent.letter_capacity = data_len;
        }
        copy.from_ptr(parent.letter_data.?[0..data_len], data_ptr, data_len);
    }

    result.set_ok(ctx);
}

fn read_letter(ctx: *handler.InvocationContext) void {
    const buffer_ptr = ctx.rsi;
    const buffer_len = ctx.rdx;

    const kata = sensei.get_current_kata() orelse return result.set_error(ctx);

    if (kata.letter_type == kata_constants.LETTER_NONE) {
        return result.set_value(ctx, 0);
    }

    if (kata.letter_len > 0) {
        if (!memory_limits.is_valid_kata_pointer(buffer_ptr)) return result.set_error(ctx);
        if (kata.letter_len > buffer_len) return result.set_error(ctx);

        if (kata.letter_data) |data| {
            copy.to_ptr(buffer_ptr, data[0..kata.letter_len]);
        }

        if (kata.letter_len < buffer_len) {
            slice.byte_ptr(buffer_ptr)[kata.letter_len] = 0;
        }
    }

    const letter_type = kata.letter_type;
    kata.letter_type = kata_constants.LETTER_NONE;
    kata.letter_len = 0;

    result.set_value(ctx, letter_type);
}
