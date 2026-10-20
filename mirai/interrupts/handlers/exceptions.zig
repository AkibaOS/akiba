//! Exception Handler Stubs (Vectors 0-31)

const common = @import("common");
const cpu = @import("asm").cpu;
const crimson = @import("mirai").crimson;
const frame = @import("mirai").interrupts.types.frame;
const metadata = @import("mirai").interrupts.constants.idt.exceptions;
const stubgen = @import("asm").interrupts.stubs;
const user = @import("mirai").thread.user;

const vectors = common.constants.interrupts.vectors;

const InterruptFrame = frame.InterruptFrame;

export fn exception_dispatch(interrupt_frame: *InterruptFrame) void {
    const vector: u8 = @truncate(interrupt_frame.Vector);
    if ((interrupt_frame.CS & cpu.constants.user.SELECTOR_RPL_MASK) == cpu.constants.user.SELECTOR_RPL_USER and
        vector != vectors.NMI_VECTOR and vector != vectors.DOUBLE_FAULT_VECTOR and vector != vectors.MACHINE_CHECK_VECTOR)
    {
        const address = if (vector == crimson.constants.vectors.PAGE_FAULT_VECTOR) cpu.control.readCR2() else interrupt_frame.RIP;
        user.fault(vector, interrupt_frame.ErrorCode, address, interrupt_frame.RIP, interrupt_frame.RSP);
    }

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
        array[vector] = &stubgen.makeExceptionHandler(@intCast(vector), metadata.HAS_ERROR_CODE[vector]);
    }
    break :blk array;
};
