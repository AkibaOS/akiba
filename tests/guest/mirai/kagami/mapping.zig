//! Disposable Root Mapping Regressions

const std = @import("std");

const common = @import("common");
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").constants.memory;
const kagami = @import("mirai").kagami;
const labels = @import("tests").strings.memory;
const pmm = @import("mirai").pmm;
const verify = @import("tests").guest.support.verify;

const protection = kagami.constants.protection;
const sizes = common.constants.memory.sizes;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const before = pmm.state.getStatistics();
    const first = try pmm.allocate.single.allocatePageZeroed();
    var owns_first = true;
    defer if (owns_first) pmm.free.single.freePage(first);
    const second = try pmm.allocate.single.allocatePageZeroed();
    var owns_second = true;
    defer if (owns_second) pmm.free.single.freePage(second);
    const root = try kagami.create.create();
    defer if (kagami.create.owns(root)) {
        _ = kagami.destroy.destroy(root);
    };
    verify.require(root.Ownership == .User and root.SharesKernel and root.TablePages == 1 and
        root.ResidentPages == 0 and root.WiredPages == 0 and root.ReferenceCount == 1 and
        root.ExecutionOwners == 0 and kagami.activate.canActivate(root), labels.KAGAMI_CREATE);
    try kagami.enter.enter(root, inputs.MAP_ADDRESS, first, protection.USER_WRITE);
    const mapping = kagami.extract.lookup(root, inputs.MAP_ADDRESS + inputs.SINGLE_BYTE).?;
    verify.require(root.ResidentPages == 1 and root.TablePages == inputs.FIRST_TABLE_PAGES and
        mapping.PhysicalAddress == first + inputs.SINGLE_BYTE and mapping.PageSize == sizes.PAGE_SIZE and
        mapping.Writable and mapping.UserAccessible and !mapping.Executable and
        kagami.extract.isWritable(root, inputs.MAP_ADDRESS) and kagami.extract.isUserAccessible(root, inputs.MAP_ADDRESS) and
        !kagami.extract.isExecutable(root, inputs.MAP_ADDRESS), labels.KAGAMI_MAP);
    try kagami.enter.enter(root, inputs.MAP_NEIGHBOR, second, protection.USER_READ | protection.WIRED);
    verify.require(root.TablePages == inputs.FIRST_TABLE_PAGES, labels.KAGAMI_BRANCH);
    try kagami.enter.enter(root, inputs.MAP_BRANCH, first, protection.USER_WRITE);
    verify.require(root.TablePages == inputs.BRANCH_TABLE_PAGES, labels.KAGAMI_BRANCH);
    try kagami.enter.enter(root, inputs.MAP_DISTANT, second, protection.USER_WRITE);
    verify.require(root.TablePages == inputs.DISTANT_TABLE_PAGES and root.ResidentPages == 4 and root.WiredPages == 1, labels.KAGAMI_BRANCH);
    const before_duplicate = pmm.state.getStatistics();
    var rejected_duplicate = false;
    kagami.enter.enter(root, inputs.MAP_ADDRESS, second, protection.USER_WRITE) catch |failure| {
        rejected_duplicate = failure == error.AlreadyMapped;
    };
    verify.require(rejected_duplicate and kagami.extract.extract(root, inputs.MAP_ADDRESS).? == first and
        root.ResidentPages == 4 and root.WiredPages == 1 and root.TablePages == inputs.DISTANT_TABLE_PAGES and
        std.meta.eql(before_duplicate, pmm.state.getStatistics()), labels.KAGAMI_DUPLICATE);
    try kagami.enter.enterReplace(root, inputs.MAP_ADDRESS, second, protection.USER_WRITE | protection.WIRED);
    verify.require(root.ResidentPages == 4 and root.WiredPages == 2 and
        kagami.extract.extract(root, inputs.MAP_ADDRESS).? == second and
        pmm.state.isAllocated(first) and pmm.state.isAllocated(second) and
        std.meta.eql(before_duplicate, pmm.state.getStatistics()), labels.KAGAMI_REPLACE);
    try kagami.enter.enterReplace(root, inputs.MAP_NEIGHBOR, first, protection.USER_WRITE);
    verify.require(root.ResidentPages == 4 and root.WiredPages == 1 and
        kagami.extract.extract(root, inputs.MAP_NEIGHBOR).? == first, labels.KAGAMI_REPLACE);
    try kagami.protect.protect(root, inputs.MAP_ADDRESS, protection.USER_READ);
    verify.require(root.ResidentPages == 4 and root.WiredPages == 0 and
        kagami.extract.extract(root, inputs.MAP_ADDRESS + inputs.SINGLE_BYTE).? == second + inputs.SINGLE_BYTE and
        !kagami.extract.isWritable(root, inputs.MAP_ADDRESS) and !kagami.extract.isExecutable(root, inputs.MAP_ADDRESS), labels.KAGAMI_PROTECT);
    verify.require(kagami.protect.protectRange(root, inputs.MAP_ADDRESS, inputs.MAP_RANGE_PAGES, protection.USER_READ | protection.WIRED) == 2 and
        root.WiredPages == 2 and !kagami.extract.isWritable(root, inputs.MAP_NEIGHBOR), labels.KAGAMI_RANGE);
    verify.require(kagami.remove.removeRange(root, inputs.MAP_ADDRESS, inputs.MAP_RANGE_PAGES) == 2 and
        root.ResidentPages == 2 and root.WiredPages == 0 and root.TablePages == inputs.DISTANT_TABLE_PAGES - 1 and
        kagami.extract.isMapped(root, inputs.MAP_BRANCH) and kagami.extract.isMapped(root, inputs.MAP_DISTANT), labels.KAGAMI_PRUNE);
    verify.require(kagami.remove.remove(root, inputs.MAP_BRANCH).? == first and root.ResidentPages == 1 and
        root.TablePages == inputs.FIRST_TABLE_PAGES and kagami.extract.isMapped(root, inputs.MAP_DISTANT), labels.KAGAMI_PRUNE);
    verify.require(kagami.remove.remove(root, inputs.MAP_DISTANT).? == second and
        root.ResidentPages == 0 and root.WiredPages == 0 and root.TablePages == 1, labels.KAGAMI_PRUNE);
    var rejected_absent = false;
    kagami.protect.protect(root, inputs.MAP_ADDRESS, protection.USER_READ) catch |failure| {
        rejected_absent = failure == error.NotMapped;
    };
    verify.require(rejected_absent and kagami.extract.lookup(root, inputs.MAP_ADDRESS) == null and
        kagami.extract.extract(root, inputs.MAP_ADDRESS) == null and
        !kagami.extract.isMapped(root, inputs.MAP_ADDRESS) and !kagami.extract.isWritable(root, inputs.MAP_ADDRESS) and
        !kagami.extract.isUserAccessible(root, inputs.MAP_ADDRESS) and !kagami.extract.isExecutable(root, inputs.MAP_ADDRESS) and
        kagami.remove.remove(root, inputs.MAP_ADDRESS) == null and
        kagami.remove.removeRange(root, inputs.MAP_ADDRESS, inputs.MAP_RANGE_PAGES) == 0 and root.TablePages == 1, labels.KAGAMI_ABSENT);
    const destroyed = kagami.destroy.destroy(root);
    verify.require(destroyed == .Destroyed and !kagami.create.owns(root), labels.KAGAMI_FREE);
    pmm.free.single.freePage(second);
    owns_second = false;
    pmm.free.single.freePage(first);
    owns_first = false;
    verify.require(std.meta.eql(before, pmm.state.getStatistics()), labels.KAGAMI_FREE);
}
