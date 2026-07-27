//! Exception Handler Stubs (Vectors 0-31)

const common = @import("common");

const stubgen = @import("asm").interrupts.stubs;

const crimson = @import("../../crimson/crimson.zig");
const frame = @import("common.zig");

const vectors = common.constants.interrupts.vectors;

const InterruptFrame = frame.InterruptFrame;

const HAS_ERROR_CODE = blk: {
    var table = [_]bool{false} ** vectors.EXCEPTION_COUNT;
    for ([_]u8{ 8, 10, 11, 12, 13, 14, 17, 21, 29, 30 }) |vector| {
        table[vector] = true;
    }
    break :blk table;
};

export fn exception_dispatch(interrupt_frame: *InterruptFrame) void {
    const vector: u8 = @truncate(interrupt_frame.Vector);

    var context = crimson.types.context.Context{
        .RAX = interrupt_frame.RAX,
        .RBX = interrupt_frame.RBX,
        .RCX = interrupt_frame.RCX,
        .RDX = interrupt_frame.RDX,
        .RSI = interrupt_frame.RSI,
        .RDI = interrupt_frame.RDI,
        .RBP = interrupt_frame.RBP,
        .R8 = interrupt_frame.R8,
        .R9 = interrupt_frame.R9,
        .R10 = interrupt_frame.R10,
        .R11 = interrupt_frame.R11,
        .R12 = interrupt_frame.R12,
        .R13 = interrupt_frame.R13,
        .R14 = interrupt_frame.R14,
        .R15 = interrupt_frame.R15,
    };
    crimson.context.capture.captureSegments(&context);

    var exception_frame = crimson.types.frame.Frame{
        .ErrorCode = interrupt_frame.ErrorCode,
        .RIP = interrupt_frame.RIP,
        .CS = interrupt_frame.CS,
        .RFLAGS = interrupt_frame.RFLAGS,
        .RSP = interrupt_frame.RSP,
        .SS = interrupt_frame.SS,
    };

    var exception = crimson.handlers.entry.createException(vector, &exception_frame, &context);

    const action = crimson.handlers.entry.dispatch(&exception);

    if (action.isFatal()) {
        crimson.panic.collapse.collapse(exception.getTypeName(), &exception);
    }
}

pub const stubs = blk: {
    var array: [vectors.EXCEPTION_COUNT]*const fn () callconv(.naked) void = undefined;
    for (0..vectors.EXCEPTION_COUNT) |vector| {
        array[vector] = &stubgen.makeExceptionHandler(@intCast(vector), HAS_ERROR_CODE[vector]);
    }
    break :blk array;
};
