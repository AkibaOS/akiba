//! Guest Check Assertions

const guard = @import("asm").interrupts.guard;
const labels = @import("checks").strings.guest;
const serial = @import("mirai").drivers.serial.write;

var passed: u64 = 0;

pub fn require(condition: bool, comptime name: []const u8) void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!condition) {
        serial.printf(labels.FAIL, .{name});
        @panic(labels.FAILURE);
    }
    passed += 1;
    serial.printf(labels.PASS, .{name});
}

pub fn failure(reason: anyerror) noreturn {
    serial.printf(labels.OPERATION_FAILED, .{@errorName(reason)});
    @panic(labels.FAILURE);
}

pub fn count() u64 {
    return passed;
}
