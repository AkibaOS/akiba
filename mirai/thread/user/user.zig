//! Validated User Thread Construction And Entry

const common = @import("common");
const construction = @import("mirai").thread.create;
const cpu = @import("asm").cpu;
const destruction = @import("mirai").thread.destroy;
const errors = @import("mirai").thread.errors.ownership;
const guard = @import("asm").interrupts.guard;
const kagami = @import("mirai").kagami;
const kata = @import("mirai").kata;
const limits = @import("mirai").thread.constants.user;
const messages = @import("mirai").thread.strings.shift.messages;
const selectors = @import("mirai").boot.constants.gdt.selectors;
const sensei = @import("mirai").sensei;
const state = @import("mirai").thread.state;
const transfer = @import("mirai").user.copy.transfer;
const types = @import("mirai").thread.types;
const usererrors = @import("mirai").user.errors.memory;

const AllocationError = common.errors.memory.allocation.AllocationError;
const Kata = kata.types.kata.Kata;
const MappingError = common.errors.memory.mapping.MappingError;
const OwnershipError = errors.OwnershipError;
const Thread = types.thread.Thread;
const UserError = usererrors.UserError;
const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;

pub fn validReturn(thread: *const Thread, instruction: u64, stack_pointer: u64) bool {
    if (thread.Mode != .User or !kata.state.owns(thread.Owner) or thread.Owner.Permanent or
        instruction == 0 or instruction > layout.USER_SPACE_END or
        stack_pointer <= thread.User.StackBase or stack_pointer > thread.User.StackTop) return false;
    const code = kagami.tables.walk.lookup(thread.Owner.AddressSpace.PML4Physical, instruction) orelse return false;
    return code.UserAccessible and code.Executable and !code.Writable and
        transfer.validate(thread.Owner, stack_pointer - 1, 1, true);
}

fn validStack(owner: *Kata, base: u64, size: u64) bool {
    if (base < 2 * sizes.PAGE_SIZE or base % sizes.PAGE_SIZE != 0 or size == 0 or
        size % sizes.PAGE_SIZE != 0 or size / sizes.PAGE_SIZE > limits.MAX_STACK_PAGES or
        base > layout.USER_SPACE_END or size > layout.USER_SPACE_END - base) return false;
    const top = base + size;
    if (kagami.tables.walk.lookup(owner.AddressSpace.PML4Physical, base - sizes.PAGE_SIZE) != null or
        kagami.tables.walk.lookup(owner.AddressSpace.PML4Physical, top) != null) return false;
    var address = base;
    while (address < top) : (address += sizes.PAGE_SIZE) {
        const page = kagami.tables.walk.lookup(owner.AddressSpace.PML4Physical, address) orelse return false;
        if (!page.UserAccessible or !page.Writable or page.Executable or
            !transfer.validate(owner, address, sizes.PAGE_SIZE, true)) return false;
    }
    return true;
}

pub fn create(owner: *Kata, instruction: u64, stack_base: u64, stack_size: u64, argument: u64) (AllocationError || MappingError || OwnershipError || UserError)!*Thread {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!kata.state.owns(owner) or owner.Permanent) return OwnershipError.InvalidOwner;
    if (!validStack(owner, stack_base, stack_size)) return OwnershipError.InvalidState;
    const target = try construction.create(owner, enterUser, null);
    errdefer destruction.destroy(target) catch @panic(messages.INVALID_CONTEXT);
    target.Mode = .User;
    target.User = .{
        .RIP = instruction,
        .RSP = stack_base + stack_size - limits.ENTRY_STACK_BYTES,
        .StackBase = stack_base,
        .StackTop = stack_base + stack_size,
        .Argument = argument,
    };
    target.Argument = @ptrCast(target);
    if (!validReturn(target, instruction, target.User.RSP) or
        target.User.RSP % cpu.constants.user.STACK_ALIGNMENT != 0) return OwnershipError.InvalidState;
    const initial = [_]u8{0} ** limits.ENTRY_STACK_BYTES;
    try transfer.write(owner, target.User.RSP, &initial);
    return target;
}

pub fn fault(vector: u64, code: u64, address: u64, instruction: u64, stack_pointer: u64) noreturn {
    const target = state.getCurrent() orelse @panic(messages.INVALID_CONTEXT);
    if (target.Mode != .User or !target.Managed or target.Status != .Running) @panic(messages.INVALID_CONTEXT);
    target.User.Faulted = true;
    target.User.FaultVector = vector;
    target.User.FaultCode = code;
    target.User.FaultAddress = address;
    target.User.FaultRIP = instruction;
    target.User.FaultRSP = stack_pointer;
    cpu.user.resumeKernel(target.Stack.Top, stopFaulted, @ptrCast(target));
}

fn stopFaulted(argument: *anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    const target: *Thread = @ptrCast(@alignCast(argument));
    if (state.getCurrent() != target or !target.User.Faulted) @panic(messages.INVALID_CONTEXT);
    sensei.run.stopCurrent();
}

fn enterUser(argument: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    const target: *Thread = @ptrCast(@alignCast(argument orelse @panic(messages.INVALID_CONTEXT)));
    if (state.getCurrent() != target or !target.Started or !validReturn(target, target.User.RIP, target.User.RSP) or
        (cpu.state.readFlags() & cpu.constants.control.RFLAGS_INTERRUPT_ENABLE) != 0) @panic(messages.INVALID_CONTEXT);
    const entry = cpu.types.user.Entry{
        .RIP = target.User.RIP,
        .RSP = target.User.RSP,
        .RFLAGS = cpu.constants.user.RFLAGS_INITIAL,
        .CS = @as(u64, selectors.USER_CODE_SELECTOR) | selectors.RING_3,
        .SS = @as(u64, selectors.USER_DATA_SELECTOR) | selectors.RING_3,
        .Argument = target.User.Argument,
        .FPUAddress = @intFromPtr(&target.Context.FPU),
    };
    cpu.user.enter(&entry);
}
