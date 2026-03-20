//! Raise Hardware Exception

const types = @import("../types/types.zig");
const constants = @import("../constants/constants.zig");
const handlers = @import("../handlers/handlers.zig");

const Exception = types.Exception;
const Context = types.Context;
const Frame = types.Frame;
const Action = constants.Action;

pub fn raise_from_vector(vector: u8, frame: *Frame, context: *Context) Action {
    var exception = handlers.create_exception(vector, frame, context);
    return handlers.dispatch(&exception);
}

pub fn raise_from_interrupt(vector: u8, error_code: u64, rip: u64, rsp: u64) Action {
    var context = handlers.get_exception_context();
    context.rip = rip;
    context.rsp = rsp;

    var frame = Frame{
        .error_code = error_code,
        .rip = rip,
        .cs = 0x08,
        .rflags = 0,
        .rsp = rsp,
        .ss = 0x10,
    };

    var exception = handlers.create_exception(vector, &frame, context);
    return handlers.dispatch(&exception);
}
