//! Shatter Handler (Debug, Breakpoint)

const types = @import("../types/types.zig");
const constants = @import("../constants/constants.zig");
const Exception = types.Exception;
const Action = constants.Action;

pub fn handle(exception: *Exception) Action {
    _ = exception;
    return .debug;
}
