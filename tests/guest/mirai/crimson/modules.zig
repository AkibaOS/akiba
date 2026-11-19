//! Crimson Diagnostic Module Registration Boundaries

const std = @import("std");

const crimson = @import("mirai").crimson;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").guest.constants.crimson;
const labels = @import("tests").guest.strings.crimson;
const verify = @import("tests").guest.support.verify;

pub fn run() void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const modules = crimson.render.modules;
    modules.clearModules();
    defer modules.clearModules();
    verify.require(!modules.registerModule(&inputs.MODULE_LONG_NAME, inputs.MODULE_BASE, inputs.MODULE_SIZE) and
        modules.findModuleForAddress(inputs.MODULE_BASE) == null, labels.MODULE_NAME);
    const name = inputs.MODULE_LONG_NAME[0 .. crimson.constants.limits.MODULE_NAME_CAPACITY - 1];
    const registered = modules.registerModule(name, inputs.MODULE_BASE, inputs.MODULE_SIZE);
    const found = modules.findModuleForAddress(inputs.MODULE_BASE);
    verify.require(registered and found != null and found.?.NameLength == name.len and
        std.mem.eql(u8, name, found.?.Name[0..found.?.NameLength]) and
        modules.findModuleForAddress(inputs.MODULE_BASE + inputs.MODULE_SIZE) == null, labels.MODULE_BOUNDARY);
    verify.require(!modules.registerModule(name, std.math.maxInt(u64) - 1, inputs.MODULE_SIZE), labels.MODULE_RANGE);
    for (1..crimson.constants.limits.MAX_MODULES) |index| {
        verify.require(modules.registerModule(name, inputs.MODULE_BASE + index * inputs.MODULE_SIZE, inputs.MODULE_SIZE), labels.MODULE_AVAILABLE);
    }
    verify.require(!modules.registerModule(name, inputs.MODULE_BASE + crimson.constants.limits.MAX_MODULES * inputs.MODULE_SIZE, inputs.MODULE_SIZE) and modules.findModuleForAddress(inputs.MODULE_BASE) == found, labels.MODULE_CAPACITY);
}
