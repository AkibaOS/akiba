//! Explicit Guest Regression Execution

const guest = @import("tests").guest;
const labels = @import("tests").strings.guest;
const serial = @import("mirai").drivers.serial.write;
const verify = @import("tests").verify;

pub fn execute() void {
    serial.printf(labels.BEGIN, .{});
    serial.printf(labels.GROUP_MEMORY, .{});
    guest.mirai.user.memory.run() catch |failure| verify.failure(failure);
    serial.printf(labels.GROUP_LIFECYCLE, .{});
    guest.mirai.kata.lifecycle.run() catch |failure| verify.failure(failure);
    serial.printf(labels.GROUP_COMPLETION, .{});
    guest.mirai.kata.completion.run() catch |failure| verify.failure(failure);
    serial.printf(labels.GROUP_PERSONA, .{});
    guest.mirai.thread.persona.run() catch |failure| verify.failure(failure);
    serial.printf(labels.GROUP_TERMINATION, .{});
    guest.mirai.invocations.termination.run() catch |failure| verify.failure(failure);
    serial.printf(labels.COMPLETE, .{verify.count()});
}
