//! Persona Construction Rollback And Managed Destruction Refusal

const std = @import("std");

const common = @import("common");
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").constants.guest;
const kata = @import("mirai").kata;
const labels = @import("tests").strings.context;
const memory = @import("mirai").memory;
const pmm = @import("mirai").pmm;
const sensei = @import("mirai").sensei;
const support = @import("tests").guest.mirai.sensei.support;
const thread = @import("mirai").thread;
const user = @import("mirai").user;
const verify = @import("tests").verify;

const Kata = kata.types.kata.Kata;
const PAGE_SIZE = common.constants.memory.sizes.PAGE_SIZE;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const owner = try kata.create.create();
    const identifier = owner.ID;
    defer support.dispose(identifier) catch |failure| verify.failure(failure);
    try user.memory.allocate.allocate(owner, inputs.CODE_ADDRESS);
    try user.memory.allocate.allocate(owner, inputs.STACK_ADDRESS);
    try user.memory.load.load(owner, inputs.CODE_ADDRESS, &inputs.INVALID_OPCODE);
    try user.memory.finalize.finalize(owner, inputs.CODE_ADDRESS, .ReadExecute);
    try user.memory.finalize.finalize(owner, inputs.STACK_ADDRESS, .ReadWrite);
    const warmed = try thread.user.create(owner, inputs.CODE_ADDRESS, inputs.STACK_ADDRESS, PAGE_SIZE, inputs.ENTRY_ARGUMENT);
    const stack_base = warmed.Stack.Base;
    verify.require(warmed.Mode == .Persona and warmed.User.Argument == inputs.ENTRY_ARGUMENT and
        owner.State == .Born and owner.ThreadCount == 1 and owner.LiveThreadCount == 0 and
        thread.user.validReturn(warmed, inputs.CODE_ADDRESS, warmed.User.RSP), labels.CONSTRUCTION_VALID);
    try thread.destroy.destroy(warmed);
    const before = pmm.state.getStatistics();
    const free_stacks = memory.stack.state.getState().FreeCount;
    const references = owner.AddressSpace.?.ReferenceCount;
    const descriptors = occupied();
    verify.require(rejects(owner, 0, inputs.STACK_ADDRESS, PAGE_SIZE) and
        rejects(owner, inputs.STACK_ADDRESS, inputs.STACK_ADDRESS, PAGE_SIZE) and
        rejects(owner, inputs.CODE_ADDRESS + PAGE_SIZE, inputs.STACK_ADDRESS, PAGE_SIZE), labels.CONSTRUCTION_ENTRY);
    verify.require(rejects(owner, inputs.CODE_ADDRESS, inputs.STACK_ADDRESS, 0) and
        rejects(owner, inputs.CODE_ADDRESS, inputs.STACK_ADDRESS + 1, PAGE_SIZE) and
        rejects(owner, inputs.CODE_ADDRESS, inputs.STACK_ADDRESS, PAGE_SIZE + 1), labels.CONSTRUCTION_STACK);
    verify.require(owner.State == .Born and owner.ThreadCount == 0 and owner.LiveThreadCount == 0 and
        owner.AddressSpace.?.ReferenceCount == references and occupied() == descriptors and !thread.state.owns(warmed) and
        !memory.stack.state.isPinned(stack_base) and memory.stack.state.getState().FreeCount == free_stacks and
        std.meta.eql(before, pmm.state.getStatistics()), labels.CONSTRUCTION_ROLLBACK);
    const target = try thread.user.create(owner, inputs.CODE_ADDRESS, inputs.STACK_ADDRESS, PAGE_SIZE, inputs.ENTRY_ARGUMENT);
    const managed_stack = target.Stack.Base;
    try sensei.control.start(target);
    var refused = false;
    thread.destroy.destroy(target) catch |failure| {
        refused = failure == error.InUse;
    };
    verify.require(refused and thread.state.owns(target) and target.Managed and target.Admitted and
        target.Status == .Ready and memory.stack.state.isPinned(managed_stack) and owner.ThreadCount == 1 and
        owner.LiveThreadCount == 1 and sensei.registry.find(target) != null, labels.DESTRUCTION_IN_USE);
}

fn rejects(owner: *Kata, instruction: u64, base: u64, size: u64) bool {
    const target = thread.user.create(owner, instruction, base, size, 0) catch |failure| return failure == error.InvalidState;
    thread.destroy.destroy(target) catch |failure| verify.failure(failure);
    return false;
}

fn occupied() usize {
    var count: usize = 0;
    var current = thread.state.first();
    while (current) |target| {
        count += 1;
        current = thread.state.next(target);
    }
    return count;
}
