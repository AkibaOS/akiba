//! Shatter Handler (Debug, Breakpoint)

const types = @import("../types/types.zig");

const Action = types.behavior.Action;
const Exception = types.exception.Exception;

pub fn handle(exception: *Exception) Action {
    _ = exception;
    return .Debug;
}
