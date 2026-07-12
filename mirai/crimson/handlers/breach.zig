//! Breach Handler (Page Fault, Segment Fault)

const serial = @import("../../drivers/serial/serial.zig");
const types = @import("../types/types.zig");
const constants = @import("../constants/constants.zig");
const classify = @import("../classify/classify.zig");
const messages = @import("../strings/strings.zig").messages;
const Exception = types.Exception;
const Action = constants.Action;
const PageFaultError = classify.PageFaultError;

pub fn handle(exception: *Exception) Action {
    if (exception.vector == 14) {
        const err = PageFaultError.from_error_code(exception.code);
        if (exception.context.is_kernel_mode()) {
            serial.printf(messages.KERNEL_PAGE_FAULT, .{ exception.address, err.description() });
            return .collapse;
        }
        return .@"resume";
    }
    return if (exception.context.is_kernel_mode()) .collapse else .terminate;
}
