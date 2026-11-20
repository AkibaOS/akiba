//! Commit A Prepared ELF Image To Normal Scheduler Admission

const guard = @import("asm").interrupts.guard;
const preflight = @import("mirai").bootstrap.image.preflight;
const sensei = @import("mirai").sensei;

const LaunchError = @import("mirai").bootstrap.errors.image.preparation.LaunchError;
const Prepared = @import("mirai").bootstrap.types.image.preparation.Prepared;

/// A refused start leaves the prepared image available for retry or abort.
pub fn start(image: Prepared) LaunchError!u64 {
    const flags = guard.acquire();
    defer guard.release(flags);
    const target = try preflight.check(image);
    try sensei.control.start(target);
    return image.ID;
}
