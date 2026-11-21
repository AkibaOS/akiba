//! Start The First Kata From The Exact Core Pulse Unit

const embedded = @import("shared").pulse.boot.image;
const guard = @import("asm").interrupts.guard;
const image = @import("mirai").bootstrap.image;
const install = @import("shared").pulse.strings.install;
const kata = @import("mirai").kata;
const labels = @import("mirai").bootstrap.strings.image.rollback;
const memory = @import("mirai").memory.allocator.native;
const stack = @import("mirai").bootstrap.constants.pulse.stack;
const storage = @import("mirai").bootstrap.storage.read;
const weaver = @import("mirai").bootstrap.weaver.handoff;

const Prepared = @import("mirai").bootstrap.types.image.preparation.Prepared;
const PulseError = @import("mirai").bootstrap.errors.pulse.launch.PulseError;
const Volume = @import("shared").boot.types.volume.Volume;

pub fn start(volume: Volume) !Prepared {
    const flags = guard.acquire();
    defer guard.release(flags);
    const kernel = kata.state.getKernel() orelse return PulseError.KernelOwnerMissing;
    if (kata.state.first() != null) return PulseError.NotFirstKata;
    const allocator = memory.get();
    const file = try storage.unit(volume, .{ .Parents = &install.STACKS, .Unit = install.UNIT }, allocator);
    defer allocator.free(file.Bytes);
    const payload = try embedded.weaver(file.Bytes);
    const prepared = try image.prepare.prepare(kernel, file.Bytes, .{ .StackBase = stack.BASE, .StackPages = stack.PAGES });
    errdefer image.abort.abort(prepared) catch @panic(labels.ROLLBACK_FAILED);
    if (!kata.lifecycle.designatePulse(prepared.Owner)) return PulseError.DesignationRefused;
    try weaver.arm(prepared.Owner, payload);
    errdefer if (!weaver.disarm(prepared.ID)) @panic(labels.ROLLBACK_FAILED);
    _ = try image.start.start(prepared);
    return prepared;
}
