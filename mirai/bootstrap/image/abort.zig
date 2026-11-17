//! Unpublished Bootstrap Image Abort

const guard = @import("asm").interrupts.guard;
const kagami = @import("mirai").kagami;
const kata = @import("mirai").kata;
const memory = @import("mirai").memory;
const thread = @import("mirai").thread;

const Prepared = @import("mirai").bootstrap.types.image.Prepared;
const ImageError = @import("mirai").bootstrap.errors.image.ImageError;

pub fn abort(image: Prepared) ImageError!void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const owner = image.Owner;
    if (!kata.state.owns(owner) or owner.ID != image.ID or owner.Permanent) return ImageError.InvalidImage;
    const generation = thread.state.generation(image.Thread) orelse return ImageError.InvalidImage;
    if (generation != image.ThreadGeneration or image.Thread.Owner != owner) return ImageError.InvalidImage;
    const target = image.Thread;
    const root = owner.AddressSpace;
    if (owner.State != .Born or owner.ThreadCount != 1 or owner.LiveThreadCount != 0 or
        owner.RunnableThreadCount != 0 or target.Permanent or target.Managed or target.Admitted or
        target.Status != .Ready or target == thread.state.getCurrent() or root.ReferenceCount != 1 or
        root.ExecutionOwners != 1 or root == kagami.state.getCurrentKagami() or kagami.activate.isActive(root) or
        !memory.stack.state.isPinned(target.Stack.Base)) return ImageError.InUse;
    try thread.destroy.destroy(target);
    try kata.destroy.destroy(owner);
}
