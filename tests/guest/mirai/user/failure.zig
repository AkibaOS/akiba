//! Owned Page Construction Failure Recovery

const std = @import("std");

const budget = @import("tests").guest.support.allocation;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").guest.constants.memory;
const kagami = @import("mirai").kagami;
const kata = @import("mirai").kata;
const labels = @import("tests").guest.strings.memory;
const pmm = @import("mirai").pmm;
const user = @import("mirai").user;
const verify = @import("tests").guest.support.verify;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    defer budget.clear();
    const owner = try kata.create.create();
    defer kata.destroy.destroy(owner) catch |failure| verify.failure(failure);
    try user.memory.allocate.allocate(owner, inputs.USER_ADDRESS);
    try user.memory.release.releaseAll(owner);
    const root = owner.AddressSpace.?;
    const before = pmm.state.getStatistics();
    const search = pmm.state.getState().SearchStart;
    const count = user.state.ledger.count();
    const tables = root.TablePages;
    var failures: usize = 0;
    while (true) : (failures += 1) {
        budget.arm(failures);
        if (user.memory.allocate.allocate(owner, inputs.USER_ADDRESS)) |_| {
            budget.clear();
            break;
        } else |failure| {
            budget.clear();
            verify.require(failure == error.OutOfMemory and user.state.ledger.count() == count and
                user.state.ledger.first(owner) == null and user.state.ledger.find(owner, inputs.USER_ADDRESS) == null and
                !kagami.extract.isMapped(root, inputs.USER_ADDRESS) and root.TablePages == tables and root.ResidentPages == 0 and
                pmm.state.getState().SearchStart == search and std.meta.eql(before, pmm.state.getStatistics()), labels.USER_ALLOCATION_FAILURE);
        }
    }
    verify.require(failures > 1 and root.ResidentPages == 1 and user.state.ledger.count() == count + 1, labels.USER_ALLOCATION_RECOVERY);
    budget.arm(0);
    try user.memory.release.releaseAll(owner);
    budget.clear();
    verify.require(user.state.ledger.count() == count and user.state.ledger.first(owner) == null and
        std.meta.eql(before, pmm.state.getStatistics()), labels.USER_ALLOCATION_UNWIND);
}
