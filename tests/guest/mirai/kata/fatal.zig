//! Isolated Pulse Termination Contract

const drive = @import("tests").guest.support.drive;
const guard = @import("asm").interrupts.guard;
const kata = @import("mirai").kata;
const labels = @import("tests").phase.strings.scenario;
const sensei = @import("mirai").sensei;
const serial = @import("mirai").drivers.serial.write;
const thread = @import("mirai").thread;

pub fn run() !void {
    const flags = guard.acquire();
    const owner = try kata.create.create();
    if (!kata.lifecycle.designatePulse(owner)) @panic(labels.INVALID);
    try sensei.control.start(try thread.create.create(owner, entry, null));
    serial.printf(labels.CHECKPOINT, .{});
    guard.release(flags);
    drive.run();
    @panic(labels.UNEXPECTED_RETURN);
}

fn entry(_: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    thread.finish.complete();
}
