//! Resume Execution

const types = @import("../types/types.zig");

const Exception = types.Exception;
const Context = types.Context;
const Frame = types.Frame;

pub fn resume_execution(exception: *Exception) void {
    restore_context(exception.context);
    restore_frame(exception.frame);
}

pub fn resume_with_new_context(exception: *Exception, new_context: *const Context) void {
    exception.context.* = new_context.*;
    resume_execution(exception);
}

fn restore_context(context: *Context) void {
    _ = context;
}

fn restore_frame(frame: *Frame) void {
    _ = frame;
}

pub fn can_resume(exception: *const Exception) bool {
    return exception.recoverable;
}
