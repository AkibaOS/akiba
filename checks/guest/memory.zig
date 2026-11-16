//! Owned Page Permission Regressions

const std = @import("std");

const common = @import("common");
const guard = @import("asm").interrupts.guard;
const inputs = @import("checks").constants.guest;
const kagami = @import("mirai").kagami;
const kata = @import("mirai").kata;
const labels = @import("checks").strings.guest;
const sensei = @import("mirai").sensei;
const thread = @import("mirai").thread;
const user = @import("mirai").user;
const verify = @import("checks").verify;

fn finish(_: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    thread.finish.complete();
}

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const owner = try kata.create.create();
    const id = owner.ID;
    try user.memory.allocate.allocate(owner, inputs.DATA_ADDRESS);
    try user.memory.allocate.allocate(owner, inputs.CODE_ADDRESS);
    try user.memory.load.load(owner, inputs.DATA_ADDRESS, &inputs.PAYLOAD);
    try user.memory.load.load(owner, inputs.CODE_ADDRESS, &inputs.INVALID_OPCODE);
    try user.memory.finalize.finalize(owner, inputs.DATA_ADDRESS, .ReadOnly);
    try user.memory.finalize.finalize(owner, inputs.CODE_ADDRESS, .ReadExecute);
    const data = user.state.ledger.find(owner, inputs.DATA_ADDRESS).?;
    const code = user.state.ledger.find(owner, inputs.CODE_ADDRESS).?;
    try user.state.access.validate(data, false);
    try user.state.access.validate(code, false);
    const data_mapping = user.state.checks.lookupOwned(data).?;
    const code_mapping = user.state.checks.lookupOwned(code).?;
    verify.require(!data_mapping.Writable and !data_mapping.Executable and
        !code_mapping.Writable and code_mapping.Executable, labels.MEMORY_PERMISSIONS);
    var bytes: [inputs.PAYLOAD.len]u8 = undefined;
    try user.copy.transfer.read(owner, &bytes, inputs.DATA_ADDRESS);
    verify.require(std.mem.eql(u8, &bytes, &inputs.PAYLOAD), labels.MEMORY_READ);
    var rejected_write = false;
    user.copy.transfer.write(owner, inputs.DATA_ADDRESS, &inputs.REPLACEMENT) catch |failure| {
        rejected_write = failure == error.SealedPage;
    };
    var rejected_finalization = false;
    user.memory.finalize.finalize(owner, inputs.CODE_ADDRESS, .ReadWrite) catch |failure| {
        rejected_finalization = failure == error.SealedPage;
    };
    verify.require(rejected_write and rejected_finalization, labels.MEMORY_REJECTION);
    const physical = [_]u64{ data.PA, code.PA };
    const target = try thread.create.create(owner, finish, null);
    try sensei.control.start(target);
    kata.lifecycle.die(owner, .Completed);
    var rejected_dead = false;
    user.copy.transfer.write(owner, inputs.DATA_ADDRESS, &inputs.REPLACEMENT) catch |failure| {
        rejected_dead = failure == error.InvalidOwner;
    };
    verify.require(rejected_dead, labels.MEMORY_DEAD);
    try sensei.control.detach(target);
    kata.collect.collect();
    for (physical) |address| {
        const alias = kagami.tables.walk.lookup(kagami.state.getKernelKagami().PML4Physical, common.constants.memory.layout.PHYSMAP_BASE + address).?;
        verify.require(!user.state.ledger.ownsPhysical(address) and alias.Writable and !alias.Executable, labels.MEMORY_RELEASE);
    }
    _ = try kata.completion.collect(id);
}
