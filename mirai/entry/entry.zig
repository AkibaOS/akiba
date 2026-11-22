//! Mirai ELF Executable Entry

const std = @import("std");

const force = @import("compiler").force;
const mirai = @import("mirai");

comptime {
    _ = mirai.kernel.entry.mirai_entry;
    force.all(mirai.boot);
    force.all(mirai.bootstrap);
    force.all(mirai.crimson);
    force.all(mirai.drivers);
    force.all(mirai.interrupts);
    force.all(mirai.invocations);
    force.all(mirai.kagami);
    force.all(mirai.kata);
    force.all(mirai.kernel);
    force.all(mirai.launch);
    force.all(mirai.memory);
    force.all(mirai.pmm);
    force.all(mirai.postman);
    force.all(mirai.sensei);
    force.all(mirai.thread);
    force.all(mirai.user);
}

pub const panic = std.debug.FullPanic(mirai.kernel.panic.handle);
