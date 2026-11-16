//! Explicit Guest Regression Execution

const guest = @import("checks").guest;
const labels = @import("checks").strings.guest;
const serial = @import("mirai").drivers.serial.write;
const verify = @import("checks").verify;

pub fn execute() void {
    serial.printf(labels.BEGIN, .{});
    serial.printf(labels.GROUP_MEMORY, .{});
    guest.memory.run() catch |failure| verify.failure(failure);
    serial.printf(labels.GROUP_LIFECYCLE, .{});
    guest.lifecycle.run() catch |failure| verify.failure(failure);
    serial.printf(labels.GROUP_COMPLETION, .{});
    guest.completion.run() catch |failure| verify.failure(failure);
    serial.printf(labels.GROUP_PERSONA, .{});
    guest.persona.run() catch |failure| verify.failure(failure);
    serial.printf(labels.GROUP_TERMINATION, .{});
    guest.termination.run() catch |failure| verify.failure(failure);
    serial.printf(labels.COMPLETE, .{verify.count()});
}
