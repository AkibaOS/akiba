//! Breach Handler (Page Fault, Segment Fault)

const classify = @import("../classify/classify.zig");
const constants = @import("../constants/constants.zig");
const serial = @import("../../drivers/serial/serial.zig");
const strings = @import("../strings/strings.zig");
const types = @import("../types/types.zig");

const messages = strings.messages;

const Action = types.behavior.Action;
const Exception = types.exception.Exception;
const PageFaultError = classify.analyze.PageFaultError;

pub fn handle(exception: *Exception) Action {
    if (exception.Vector == constants.vectors.PAGE_FAULT_VECTOR) {
        const fault = PageFaultError.fromErrorCode(exception.Code);
        if (exception.Context.isKernelMode()) {
            serial.write.printf(messages.KERNEL_PAGE_FAULT, .{ exception.Address, fault.description() });
            return .Collapse;
        }
        return .Resume;
    }
    return if (exception.Context.isKernelMode()) .Collapse else .Terminate;
}
