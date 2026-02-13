//! Postman invocation - Letter passing between parent and child Kata

const handler = @import("handler.zig");
const kata_mod = @import("../kata/kata.zig");
const sensei = @import("../kata/sensei.zig");
const system = @import("../system/system.zig");

const MODE_SEND: u64 = 0;
const MODE_READ: u64 = 1;

pub const Letter = struct {
    pub const NONE: u8 = 0;
    pub const NAVIGATE: u8 = 1;
};

pub fn invoke(ctx: *handler.InvocationContext) void {
    const mode = ctx.rdi;

    switch (mode) {
        MODE_SEND => send_letter(ctx),
        MODE_READ => read_letter(ctx),
        else => {
            ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        },
    }
}

fn send_letter(ctx: *handler.InvocationContext) void {
    const letter_type: u8 = @intCast(ctx.rsi & 0xFF);
    const data_ptr = ctx.rdx;
    const data_len = ctx.r10;

    if (data_len > 256) {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    }

    if (data_len > 0 and !system.is_valid_user_pointer(data_ptr)) {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    }

    const sender = sensei.get_current_kata() orelse {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    const parent = kata_mod.get_kata(sender.parent_id) orelse {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    parent.letter_type = letter_type;
    parent.letter_len = @intCast(data_len);

    if (data_len > 0) {
        const src = @as([*]const u8, @ptrFromInt(data_ptr));
        for (0..data_len) |i| {
            parent.letter_data[i] = src[i];
        }
    }

    ctx.rax = 0;
}

fn read_letter(ctx: *handler.InvocationContext) void {
    const buffer_ptr = ctx.rsi;
    const buffer_len = ctx.rdx;

    const kata = sensei.get_current_kata() orelse {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    if (kata.letter_type == Letter.NONE) {
        ctx.rax = 0;
        return;
    }

    if (kata.letter_len > 0) {
        if (!system.is_valid_user_pointer(buffer_ptr)) {
            ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
            return;
        }

        if (kata.letter_len > buffer_len) {
            ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
            return;
        }

        const dest = @as([*]u8, @ptrFromInt(buffer_ptr));
        for (0..kata.letter_len) |i| {
            dest[i] = kata.letter_data[i];
        }

        if (kata.letter_len < buffer_len) {
            dest[kata.letter_len] = 0;
        }
    }

    const letter_type = kata.letter_type;
    kata.letter_type = Letter.NONE;
    kata.letter_len = 0;

    ctx.rax = letter_type;
}
