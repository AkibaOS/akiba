//! Exception Structure

const constants = @import("../constants/constants.zig");
const Context = @import("context.zig").Context;
const Frame = @import("frame.zig").Frame;
const ExceptionType = constants.ExceptionType;

pub const Exception = struct {
    exception_type: ExceptionType,
    code: u64,
    subcode: u64,
    vector: u8,
    address: u64,
    context: *Context,
    frame: *Frame,
    kata_id: u64,
    thread_id: u64,
    recoverable: bool,

    pub fn is_kernel(self: *const Exception) bool {
        return self.kata_id == 0;
    }
    pub fn is_user(self: *const Exception) bool {
        return self.kata_id != 0;
    }
    pub fn is_page_fault(self: *const Exception) bool {
        return self.vector == 14;
    }
    pub fn is_fatal(self: *const Exception) bool {
        return !self.recoverable;
    }
    pub fn get_type_name(self: *const Exception) []const u8 {
        return self.exception_type.name();
    }
};
