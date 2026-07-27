//! Forbidden Handler (Invalid Opcode, GPF)

const serial = @import("../../drivers/serial/serial.zig");
const strings = @import("../strings/strings.zig");
const types = @import("../types/types.zig");

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
