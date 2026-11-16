//! Explicitly Selected Crimson Collapse Probe

const crimson = @import("mirai").crimson;
const labels = @import("tests").strings.scenario;
const serial = @import("mirai").drivers.serial.write;

pub fn run() noreturn {
    serial.printf(labels.COLLAPSE_CHECKPOINT, .{});
    crimson.panic.collapse.collapse(labels.COLLAPSE_MESSAGE, null);
}
