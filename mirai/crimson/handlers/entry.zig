//! Common Handler Entry

const types = @import("../types/types.zig");
const constants = @import("../constants/constants.zig");
const classify = @import("../classify/classify.zig");
const context_ops = @import("../context/context.zig");

const Exception = types.Exception;
const Context = types.Context;
const Frame = types.Frame;
const ExceptionType = constants.ExceptionType;
const Action = constants.Action;

var exception_context: Context = undefined;

pub fn create_exception(vector: u8, frame: *Frame, regs: *Context) Exception {
    context_ops.capture_from_frame(regs, frame);
    const exception_type = classify.classify_vector(vector);
    return Exception{
        .exception_type = exception_type,
        .code = frame.error_code,
        .subcode = 0,
        .vector = vector,
        .address = regs.cr2,
        .context = regs,
        .frame = frame,
        .kata_id = 0,
        .thread_id = 0,
        .recoverable = exception_type.is_recoverable(),
    };
}

pub fn get_exception_context() *Context {
    return &exception_context;
}

pub fn default_action(exception_type: ExceptionType) Action {
    return switch (exception_type) {
        .breach => .@"resume",
        .shatter => .debug,
        .critical, .collapse => .collapse,
        else => .terminate,
    };
}
