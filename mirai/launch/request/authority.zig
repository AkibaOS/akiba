//! Kernel Assignment Of Ordinary Launch Construction Authority

const guard = @import("asm").interrupts.guard;
const kata = @import("mirai").kata;

const Kata = kata.types.kata.Kata;

pub fn grant(owner: *Kata) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!kata.state.owns(owner) or owner.Permanent or owner.State != .Born or owner.CanProvision) return false;
    owner.CanProvision = true;
    return true;
}
