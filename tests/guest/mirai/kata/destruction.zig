//! Atomic Kata Teardown Refusal With Live Owned Payload

const std = @import("std");

const budget = @import("tests").guest.support.allocation;
const common = @import("common");
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").constants.memory;
const kagami = @import("mirai").kagami;
const kata = @import("mirai").kata;
const labels = @import("tests").strings.tables;
const pmm = @import("mirai").pmm;
const user = @import("mirai").user;
const verify = @import("tests").guest.support.verify;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    defer budget.clear();
    const owner = try kata.create.create();
    const id = owner.ID;
    const root = owner.AddressSpace.?;
    try user.memory.allocate.allocate(owner, inputs.USER_ADDRESS);
    const record = user.state.ledger.find(owner, inputs.USER_ADDRESS).?;
    const bytes: [*]u8 = @ptrFromInt(common.constants.memory.layout.PHYSMAP_BASE + record.Backing.PA);
    @memset(bytes[0..common.constants.memory.sizes.PAGE_SIZE], inputs.DIRTY_BYTE);
    const upper = &kagami.tables.walk.getPML4(root.PML4Physical).Entries[kagami.constants.tables.KERNEL_PML4_START];
    const saved = upper.*;
    budget.arm(0);
    upper.UserAccessible = true;
    refused(owner);
    upper.* = saved;
    root.TablePages += 1;
    refused(owner);
    root.TablePages -= 1;
    try kata.destroy.destroy(owner);
    budget.clear();
    verify.require(kata.state.findByID(id) == null and !kagami.create.owns(root) and
        user.state.ledger.findRoot(root, inputs.USER_ADDRESS) == null and
        kata.completion.storage.find(id) == null, labels.KATA_GRAPH_RECOVERY);
}

fn refused(owner: *kata.types.kata.Kata) void {
    const root = owner.AddressSpace.?;
    const id = owner.ID;
    const record = user.state.ledger.find(owner, inputs.USER_ADDRESS).?;
    const physical = record.Backing.PA;
    const tables = root.TablePages;
    const frames = root.Frames;
    const residents = root.ResidentPages;
    const ledger_count = user.state.ledger.count();
    const completion = kata.completion.storage.find(id);
    const before = pmm.state.getStatistics();
    const search = pmm.state.getState().SearchStart;
    const rejected = if (kata.destroy.destroy(owner)) |_| false else |failure| failure == error.InvalidState;
    verify.require(rejected, labels.KATA_GRAPH_REFUSAL);
    verify.require(kata.state.owns(owner) and owner.State == .Born and owner.AddressSpace == root and
        kata.state.findByID(id) == owner and kagami.create.owns(root) and root.ReferenceCount == 1 and root.ExecutionOwners == 1 and
        root.TablePages == tables and root.Frames == frames and root.ResidentPages == residents and
        user.state.ledger.count() == ledger_count and user.state.ledger.find(owner, inputs.USER_ADDRESS) == record and
        kagami.extract.extract(root, inputs.USER_ADDRESS) == physical and
        kata.completion.storage.find(id) == completion and kata.completion.lifetime.peek(id) == null and
        std.meta.eql(before, pmm.state.getStatistics()) and pmm.state.getState().SearchStart == search, labels.KATA_GRAPH_PRESERVE);
    const bytes: [*]const u8 = @ptrFromInt(common.constants.memory.layout.PHYSMAP_BASE + physical);
    verify.require(std.mem.allEqual(u8, bytes[0..common.constants.memory.sizes.PAGE_SIZE], inputs.DIRTY_BYTE), labels.KATA_GRAPH_CONTENT);
}
