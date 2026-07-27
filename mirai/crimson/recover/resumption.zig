//! Resume Execution

const types = @import("../types/types.zig");

const Context = types.context.Context;
const Exception = types.exception.Exception;
const Frame = types.frame.Frame;

pub fn resumeExecution(exception: *Exception) void {
    restoreContext(exception.Context);
    restoreFrame(exception.Frame);
}

pub fn resumeWithNewContext(exception: *Exception, new_context: *const Context) void {
    exception.Context.* = new_context.*;
    resumeExecution(exception);
}

fn restoreContext(context: *Context) void {
    _ = context;
}

fn restoreFrame(frame: *Frame) void {
    _ = frame;
}

pub fn canResume(exception: *const Exception) bool {
    return exception.Recoverable;
}
