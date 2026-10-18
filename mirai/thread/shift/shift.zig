//! Validated Cooperative Thread Transfer

const common = @import("common");
const cpu = @import("asm").cpu;
const errors = @import("mirai").thread.errors.ownership;
const kagami = @import("mirai").kagami;
const kata = @import("mirai").kata;
const messages = @import("mirai").thread.strings.shift.messages;
const stacks = @import("mirai").memory.stack;
const state = @import("mirai").thread.state;
const synchronize = @import("mirai").kagami.synchronize;
const tss = @import("mirai").boot.tss;
const types = @import("mirai").thread.types;

const indices = common.constants.paging.indices;
const OwnershipError = errors.OwnershipError;
const State = types.state.State;
const Thread = types.thread.Thread;

fn hasOwner(thread: *const Thread) bool {
    return state.owns(thread) and kata.state.owns(thread.Owner) and thread.Owner.ThreadCount != 0 and
        thread.Owner.AddressSpace.ExecutionOwners != 0 and stacks.state.isPinned(thread.Stack.Base);
}

fn isCurrentValid(thread: *const Thread) bool {
    if (!hasOwner(thread) or thread.Status != .Running) return false;
    const pointer = cpu.state.readStackPointer();
    return pointer >= thread.Stack.Base and pointer < thread.Stack.Top and
        kagami.state.getCurrentKagami() == thread.Owner.AddressSpace and
        (cpu.control.readCR3() & indices.ADDRESS_MASK) == thread.Owner.AddressSpace.PML4Physical and
        tss.state.getBootTSS().RSP0 == thread.Stack.Top;
}

fn canResume(thread: *const Thread) bool {
    if (!hasOwner(thread) or thread.Status != .Ready or !kagami.activate.canActivate(thread.Owner.AddressSpace)) return false;
    const context = &thread.Context;
    const text = kagami.state.getPolicy().Image.Text;
    return context.CR3 == thread.Owner.AddressSpace.PML4Physical and
        context.RSP >= thread.Stack.Base + 2 * @sizeOf(u64) and context.RSP <= thread.Stack.Top - @sizeOf(u64) and
        context.RIP >= text.VirtualStart and context.RIP < text.VirtualEnd and
        (context.RFLAGS & cpu.constants.control.RFLAGS_RESERVED) != 0 and
        (context.RFLAGS & (cpu.constants.control.RFLAGS_INTERRUPT_ENABLE | cpu.constants.control.RFLAGS_DIRECTION)) == 0;
}

pub fn shift(next: *Thread) OwnershipError!void {
    return transfer(next, .Ready, false);
}

pub fn dispatch(next: *Thread, previous_status: State) OwnershipError!void {
    if (previous_status != .Ready and previous_status != .Blocked) return OwnershipError.InvalidState;
    return transfer(next, previous_status, true);
}

fn transfer(next: *Thread, previous_status: State, managed: bool) OwnershipError!void {
    const previous_flags = synchronize.acquire();
    defer synchronize.release(previous_flags);
    const previous = state.getCurrent() orelse return OwnershipError.NotInitialized;
    if (!isCurrentValid(previous)) return OwnershipError.InvalidState;
    if (!state.owns(next)) return OwnershipError.InvalidThread;
    if (previous.Managed != managed or next.Managed != managed) return OwnershipError.InUse;
    if (next == previous) {
        if (previous_status != .Ready) return OwnershipError.InvalidState;
        return;
    }
    if (!canResume(next) or
        (cpu.control.readCR4() & cpu.constants.control.CR4_OS_XSAVE) != 0 or
        (cpu.control.readCR0() & (cpu.constants.control.CR0_EMULATION | cpu.constants.control.CR0_TASK_SWITCHED)) != 0)
        return OwnershipError.InvalidState;
    previous.Status = previous_status;
    next.Status = .Running;
    if (!state.setCurrent(next)) @panic(messages.INVALID_CONTEXT);
    tss.state.getBootTSS().setRSP0(next.Stack.Top);
    cpu.context.transfer(&previous.Context, &next.Context);
    if (!finish()) @panic(messages.INVALID_CONTEXT);
}

pub fn finish() bool {
    const current = state.getCurrent() orelse return false;
    if (!hasOwner(current) or current.Status != .Running or
        (cpu.state.readFlags() & cpu.constants.control.RFLAGS_INTERRUPT_ENABLE) != 0) return false;
    const pointer = cpu.state.readStackPointer();
    if (pointer < current.Stack.Base or pointer >= current.Stack.Top or
        (cpu.control.readCR3() & indices.ADDRESS_MASK) != current.Owner.AddressSpace.PML4Physical or
        tss.state.getBootTSS().RSP0 != current.Stack.Top) return false;
    kagami.state.setCurrentKagami(current.Owner.AddressSpace);
    return kagami.state.getCurrentKagami() == current.Owner.AddressSpace;
}
