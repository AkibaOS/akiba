//! Guest Check Assertions

const guard = @import("asm").interrupts.guard;
const labels = @import("tests").strings.guest;
const screen = @import("tests").guest.screen.control;
const serial = @import("mirai").drivers.serial.write;

var passed: u64 = 0;

pub fn require(condition: bool, comptime name: []const u8) void {
    if (!condition) {
        screen.fail(name);
        const flags = guard.acquire();
        defer guard.release(flags);
        serial.printf(labels.FAIL, .{name});
        @panic(labels.FAILURE);
    }
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    passed += 1;
    screen.record(.Pass, name);
    serial.printf(labels.PASS, .{name});
}

pub fn failure(reason: anyerror) noreturn {
    const detail = @errorName(reason);
    screen.fail(detail);
    serial.printf(labels.OPERATION_FAILED, .{detail});
    @panic(labels.FAILURE);
}

pub fn count() u64 {
    return passed;
}
