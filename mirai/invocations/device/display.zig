//! Dispatch Private Display Mode And Row Calls

const std = @import("std");

const copy = @import("mirai").user.copy.transfer;
const frame = @import("mirai").device.display.frame;

const InterruptFrame = @import("mirai").interrupts.types.frame.InterruptFrame;
const Operation = @import("shared").display.types.operation.Operation;
const Row = @import("shared").display.types.operation.Row;
const Status = @import("shared").persona.types.invocation.Status;
const Thread = @import("mirai").thread.types.thread.Thread;

pub fn dispatch(caller: *Thread, registers: *InterruptFrame) void {
    perform(caller, registers) catch |failure| {
        registers.RAX = @intFromEnum(status(failure));
        registers.RDX = 0;
        return;
    };
    registers.RAX = @intFromEnum(Status.Success);
    registers.RDX = 0;
}

fn perform(caller: *Thread, registers: *const InterruptFrame) !void {
    try frame.check(caller);
    if (registers.RDX != 0 or registers.R10 != 0) return error.InvalidArgument;
    switch (std.enums.fromInt(Operation, registers.RDI) orelse return error.InvalidArgument) {
        .Describe => {
            const info = try frame.mode();
            try copy.write(caller.Owner, registers.RSI, std.mem.asBytes(&info));
        },
        .PresentRow => {
            var row: Row = undefined;
            try copy.read(caller.Owner, std.mem.asBytes(&row), registers.RSI);
            try frame.present(caller, row);
        },
    }
}

fn status(failure: anyerror) Status {
    return switch (failure) {
        error.InvalidArgument => .InvalidArgument,
        error.InvalidCaller, error.InvalidThread => .InvalidCaller,
        error.NotInitialized => .NotInitialized,
        error.InvalidUserRange, error.InvalidAddress, error.NotOwned, error.InvalidOwnedMapping, error.InvalidPhysmap, error.SealedPage => .InvalidAddress,
        else => .InvalidState,
    };
}
