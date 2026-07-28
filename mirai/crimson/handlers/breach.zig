//! Breach Handler (Page Fault, Segment Fault)

const classify = @import("mirai").crimson.classify;
const constants = @import("mirai").crimson.constants;
const serial = @import("mirai").drivers.serial;
const strings = @import("mirai").crimson.strings;
const types = @import("mirai").crimson.types;

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
