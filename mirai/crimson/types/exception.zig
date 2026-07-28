//! Exception Structure

const constants = @import("mirai").crimson.constants;
const context = @import("mirai").crimson.types.context;
const frame = @import("mirai").crimson.types.frame;
const kind = @import("mirai").crimson.types.kind;

const vectors = constants.vectors;

pub const Exception = struct {
    ExceptionType: kind.ExceptionType,
    Code: u64,
    Subcode: u64,
    Vector: u8,
    Address: u64,
    Context: *context.Context,
    Frame: *frame.Frame,
    KataId: u64,
    ThreadId: u64,
    Recoverable: bool,

    pub fn isKernel(self: *const Exception) bool {
        return self.KataId == 0;
    }

    pub fn isUser(self: *const Exception) bool {
        return self.KataId != 0;
    }

    pub fn isPageFault(self: *const Exception) bool {
        return self.Vector == vectors.PAGE_FAULT_VECTOR;
    }

    pub fn isFatal(self: *const Exception) bool {
        return !self.Recoverable;
    }

    pub fn getTypeName(self: *const Exception) []const u8 {
        return self.ExceptionType.name();
    }
};
