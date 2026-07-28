//! Raise Hardware Exception

const boot = @import("mirai").boot;
const entry = @import("mirai").crimson.handlers.entry;
const types = @import("mirai").crimson.types;

const selectors = boot.constants.gdt.selectors;

const Action = types.behavior.Action;
const Context = types.context.Context;
const Frame = types.frame.Frame;

pub fn raiseFromVector(vector: u8, frame: *Frame, context: *Context) Action {
    var exception = entry.createException(vector, frame, context);
    return entry.dispatch(&exception);
}

pub fn raiseFromInterrupt(vector: u8, error_code: u64, rip: u64, rsp: u64) Action {
    var context = entry.getExceptionContext();
    context.RIP = rip;
    context.RSP = rsp;

    var frame = Frame{
        .ErrorCode = error_code,
        .RIP = rip,
        .CS = selectors.KERNEL_CODE_SELECTOR,
        .RFLAGS = 0,
        .RSP = rsp,
        .SS = selectors.KERNEL_DATA_SELECTOR,
    };

    var exception = entry.createException(vector, &frame, context);
    return entry.dispatch(&exception);
}
