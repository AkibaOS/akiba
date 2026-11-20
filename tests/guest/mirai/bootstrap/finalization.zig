//! Finalized ELF Thread Reservation Failure And Recovery

const std = @import("std");

const bootstrap = @import("mirai").bootstrap;
const budget = @import("tests").guest.support.allocation;
const fixture = @import("tests").fixtures.bytes.elf;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").fixtures.constants.elf.layout;
const kata = @import("mirai").kata;
const labels = @import("tests").guest.strings.elf;
const memory = @import("mirai").memory;
const pmm = @import("mirai").pmm;
const thread = @import("mirai").thread;
const user = @import("mirai").user;
const verify = @import("tests").guest.support.verify;

const KernelStack = memory.types.stack.kernel.KernelStack;
const VALID = fixture.create();

var identifier: u64 = 0;
var finalized: bool = false;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    defer budget.clear();
    const cursor = pmm.state.getState().SearchStart;
    defer pmm.state.getState().SearchStart = cursor;
    const warm = try prepare();
    try bootstrap.image.abort.abort(warm);
    pmm.state.getState().SearchStart = cursor;
    var held = [_]?KernelStack{null} ** memory.constants.stack.limits.CACHE_TARGET;
    defer for (held) |stack| {
        if (stack) |live| memory.stack.free.free(live);
    };
    for (&held) |*stack| stack.* = try memory.stack.allocate.allocate();
    const marker = try kata.create.create();
    identifier = marker.ID + 1;
    try kata.destroy.destroy(marker);
    const before = pmm.state.getStatistics();
    const count = user.state.ledger.count();
    finalized = false;
    budget.armWhen(afterPermissions);
    var rejected = false;
    if (prepare()) |unexpected| {
        budget.clear();
        try bootstrap.image.abort.abort(unexpected);
    } else |failure| rejected = failure == error.OutOfMemory;
    budget.clear();
    verify.require(rejected and finalized and user.state.ledger.count() == count and kata.state.findByID(identifier) == null and
        kata.completion.storage.ownerOf(identifier) == null and memory.stack.state.getState().FreeCount == 0 and
        std.meta.eql(before, pmm.state.getStatistics()), labels.FINAL_ROLLBACK);
    pmm.state.getState().SearchStart = cursor;
    const recovered = try prepare();
    const correct = recovered.ID == identifier + 1 and recovered.Owner.ThreadCount == 1;
    try bootstrap.image.abort.abort(recovered);
    for (&held) |*stack| {
        memory.stack.free.free(stack.*.?);
        stack.* = null;
    }
    _ = memory.stack.collect.collect();
    verify.require(correct and user.state.ledger.count() == count, labels.FINAL_RECOVERY);
}

fn afterPermissions() bool {
    const owner = kata.state.findByID(identifier) orelse return false;
    const code = user.state.ledger.find(owner, inputs.CODE_ADDRESS) orelse return false;
    const rodata = user.state.ledger.find(owner, inputs.CODE_ADDRESS + inputs.PAGE_BYTES) orelse return false;
    const stack = user.state.ledger.find(owner, inputs.STACK_ADDRESS + inputs.PAGE_BYTES) orelse return false;
    finalized = owner.ThreadCount == 0 and code.Backing.Stage == .Executable and rodata.Backing.Stage == .ReadOnly and stack.Backing.Stage == .Writable;
    return finalized;
}

fn prepare() !bootstrap.types.image.preparation.Prepared {
    return bootstrap.image.prepare.prepare(thread.state.getCurrent().?.Owner, &VALID, .{
        .StackBase = inputs.STACK_ADDRESS,
        .StackPages = 2,
    });
}
