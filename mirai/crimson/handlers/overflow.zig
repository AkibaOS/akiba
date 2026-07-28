//! Overflow Handler (Arithmetic Exceptions)

const serial = @import("mirai").drivers.serial;
const strings = @import("mirai").crimson.strings;
const types = @import("mirai").crimson.types;

const messages = strings.messages;

const Action = types.behavior.Action;
const Exception = types.exception.Exception;

pub fn handle(exception: *Exception) Action {
    if (exception.Context.isKernelMode()) {
        serial.write.printf(messages.KERNEL_ARITHMETIC, .{exception.Context.RIP});
        return .Collapse;
    }
    return .Terminate;
}
