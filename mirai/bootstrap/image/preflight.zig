//! Ensure An ELF Image Is Still The Original Unpublished Transaction

const std = @import("std");

const control = @import("asm").cpu.constants.control.registers;
const cpu = @import("asm").cpu.state;
const kagami = @import("mirai").kagami;
const kata = @import("mirai").kata;
const memory = @import("mirai").memory;
const thread = @import("mirai").thread;

const ImageError = @import("mirai").bootstrap.errors.image.ImageError;
const Prepared = @import("mirai").bootstrap.types.image.Prepared;
const Thread = thread.types.thread.Thread;

/// Keep the caller's interrupt guard until admission or destruction completes.
pub fn check(image: Prepared) ImageError!*Thread {
    std.debug.assert(cpu.readFlags() & control.RFLAGS_INTERRUPT_ENABLE == 0);
    const owner = image.Owner;
    if (!kata.state.owns(owner) or owner.ID != image.ID or owner.Permanent) return ImageError.InvalidImage;
    const target = image.Thread;
    const generation = thread.state.generation(target) orelse return ImageError.InvalidImage;
    if (generation != image.ThreadGeneration or target.Owner != owner or target.Mode != .Persona) return ImageError.InvalidImage;
    const root = owner.AddressSpace orelse return ImageError.InvalidImage;
    if (owner.State != .Born or owner.ThreadCount != 1 or owner.LiveThreadCount != 0 or
        owner.RunnableThreadCount != 0 or target.Permanent or target.Managed or target.Admitted or
        target.Status != .Ready or target == thread.state.getCurrent() or root.ReferenceCount != 1 or
        root.ExecutionOwners != 1 or root == kagami.state.getCurrentKagami() or kagami.activate.isActive(root) or
        !memory.stack.state.isPinned(target.Stack.Base)) return ImageError.InUse;
    return target;
}
