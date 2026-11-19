//! Physmap Split Allocation Failure And Ownership Checks

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

const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    defer budget.clear();
    const search = pmm.state.getState().SearchStart;
    defer pmm.state.getState().SearchStart = search;
    const owner = try kata.create.create();
    defer kata.destroy.destroy(owner) catch |failure| verify.failure(failure);
    const candidate = select() orelse {
        verify.require(false, labels.ALIAS_FIXTURE);
        return;
    };
    pmm.state.getState().SearchStart = candidate / sizes.PAGE_SIZE;
    try user.memory.allocate.allocate(owner, inputs.USER_ADDRESS);
    const record = user.state.ledger.find(owner, inputs.USER_ADDRESS).?;
    const physical = record.Backing.PA;
    const kernel = kagami.state.getKernelKagami();
    const original = user.state.checks.lookupAlias(record).?;
    verify.require(physical == candidate and original.PageSize > sizes.PAGE_SIZE, labels.ALIAS_FIXTURE);
    const tables = kernel.TablePages;
    const before = pmm.state.getStatistics();
    const cursor = pmm.state.getState().SearchStart;
    var failures: usize = 0;
    while (true) : (failures += 1) {
        budget.arm(failures);
        if (user.memory.finalize.finalize(owner, inputs.USER_ADDRESS, .ReadOnly)) |_| {
            budget.clear();
            break;
        } else |failure| {
            budget.clear();
            const unchanged = user.state.checks.lookupAlias(record).?;
            verify.require(failure == error.OutOfMemory and record.Backing.Stage == .Loading and kernel.TablePages == tables and
                unchanged.PageSize == original.PageSize and unchanged.Entry == original.Entry and unchanged.Writable and
                user.copy.transfer.validate(owner, inputs.USER_ADDRESS, 1, true) and kagami.tables.ownership.reset(kernel) and
                pmm.state.getState().SearchStart == cursor and std.meta.eql(before, pmm.state.getStatistics()), labels.ALIAS_FAILURE);
        }
    }
    verify.require(failures != 0 and kernel.TablePages > tables and kagami.tables.ownership.reset(kernel) and
        record.Backing.Stage == .ReadOnly and user.state.checks.lookupAlias(record).?.PageSize == sizes.PAGE_SIZE and
        !user.state.checks.lookupAlias(record).?.Writable, labels.ALIAS_RECOVERY);
    budget.arm(0);
    try user.memory.release.releaseAll(owner);
    budget.clear();
    const restored = kagami.tables.walk.lookup(kernel.PML4Physical, layout.PHYSMAP_BASE + physical).?;
    verify.require(restored.Writable and !restored.Executable and !restored.UserAccessible and
        pmm.state.getRole(physical) == .Free and
        !user.state.ledger.ownsPhysical(physical) and owner.AddressSpace.?.ResidentPages == 0, labels.ALIAS_RELEASE);
}

fn select() ?u64 {
    var next_physical: u64 = 0;
    while (pmm.state.firstFreeAtOrAfter(next_physical)) |physical| {
        next_physical = physical + sizes.PAGE_SIZE;
        const alias = kagami.tables.walk.lookup(kagami.state.getKernelKagami().PML4Physical, layout.PHYSMAP_BASE + physical) orelse continue;
        if (alias.PageSize > sizes.PAGE_SIZE and alias.Writable and !alias.Executable and !alias.UserAccessible) return physical;
    }
    return null;
}
