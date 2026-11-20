//! Unpublished Bootstrap Image Abort

const guard = @import("asm").interrupts.guard;
const kata = @import("mirai").kata;
const preflight = @import("mirai").bootstrap.image.preflight;
const thread = @import("mirai").thread;

const Prepared = @import("mirai").bootstrap.types.image.preparation.Prepared;
const ImageError = @import("mirai").bootstrap.errors.image.preparation.ImageError;

pub fn abort(image: Prepared) ImageError!void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const target = try preflight.check(image);
    try thread.destroy.destroy(target);
    try kata.destroy.destroy(image.Owner);
}
