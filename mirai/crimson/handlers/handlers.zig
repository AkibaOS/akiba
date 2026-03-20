//! Exception Handlers

const constants = @import("../constants/constants.zig");
const types = @import("../types/types.zig");
pub const entry = @import("entry.zig");
pub const breach = @import("breach.zig");
pub const forbidden = @import("forbidden.zig");
pub const overflow = @import("overflow.zig");
pub const shatter = @import("shatter.zig");
pub const missing = @import("missing.zig");
pub const collapse = @import("collapse.zig");

const Exception = types.Exception;
const ExceptionType = constants.ExceptionType;
const Action = constants.Action;

pub const create_exception = entry.create_exception;
pub const get_exception_context = entry.get_exception_context;
pub const default_action = entry.default_action;

pub fn dispatch(exception: *Exception) Action {
    return switch (exception.exception_type) {
        .breach => breach.handle(exception),
        .forbidden => forbidden.handle(exception),
        .overflow => overflow.handle(exception),
        .shatter => shatter.handle(exception),
        .missing => missing.handle(exception),
        .collapse => collapse.handle(exception),
        .critical => .collapse,
        else => .terminate,
    };
}
