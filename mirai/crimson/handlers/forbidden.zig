//! Forbidden Handler (Invalid Opcode, GPF)

const serial = @import("mirai").drivers.serial;
const strings = @import("mirai").crimson.strings;
const types = @import("mirai").crimson.types;

const messages = strings.messages;

const Action = types.behavior.Action;
const Exception = types.exception.Exception;

pub fn handle(exception: *Exception) Action {
    if (exception.Context.isKernelMode()) {
        serial.write.printf(messages.KERNEL_FORBIDDEN, .{ exception.Context.RIP, exception.Vector, exception.Code });
        return .Collapse;
    }
    return .Terminate;
}
