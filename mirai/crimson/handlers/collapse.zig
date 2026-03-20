//! Collapse Handler (Double Fault, Machine Check)

const serial = @import("../../drivers/serial/serial.zig");
const types = @import("../types/types.zig");
const constants = @import("../constants/constants.zig");
const Exception = types.Exception;
const Action = constants.Action;

pub fn handle(exception: *Exception) Action {
    serial.printf("FATAL: Unrecoverable exception (vector %d) at %x\n", .{ exception.vector, exception.context.rip });
    return .collapse;
}
