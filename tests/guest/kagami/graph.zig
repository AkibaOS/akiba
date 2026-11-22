//! Complete Table Graph Validation Before Destructive Release

const std = @import("std");

const budget = @import("tests").guest.support.allocation;
const common = @import("common");
const decompose = @import("common").paging.decompose;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").guest.constants.memory.fixtures;
const kagami = @import("mirai").kagami;
const labels = @import("tests").guest.strings.tables;
const pmm = @import("mirai").pmm;
const verify = @import("tests").guest.support.verify;

const indices = common.constants.paging.indices;
const Entry = kagami.types.entry.Entry;
const Kagami = kagami.types.kagami.Kagami;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    defer budget.clear();
    const before = pmm.state.getStatistics();
    const payload = try pmm.allocate.single.allocatePageZeroed();
    var live_payload = true;
    defer if (live_payload) pmm.free.single.freePage(payload);
    const first = try kagami.create.create();
    var live_first = true;
    defer if (live_first) verify.require(kagami.destroy.destroy(first) == .Destroyed, labels.GRAPH_RECOVERY);
    const second = try kagami.create.create();
    var live_second = true;
    defer if (live_second) verify.require(kagami.destroy.destroy(second) == .Destroyed, labels.GRAPH_RECOVERY);
    try kagami.enter.enter(first, inputs.MAP_ADDRESS, payload, kagami.constants.protection.USER_WRITE);
    try kagami.enter.enter(first, inputs.MAP_BRANCH, payload, kagami.constants.protection.USER_WRITE);
    try kagami.enter.enter(second, inputs.MAP_ADDRESS, payload, kagami.constants.protection.USER_WRITE);
    const branch = leafParent(first, inputs.MAP_BRANCH);
    const saved_branch = branch.*;
    const primary = leafParent(first, inputs.MAP_ADDRESS).*;
    const foreign = leafParent(second, inputs.MAP_ADDRESS).*;
    budget.arm(0);
    branch.* = foreign;
    refused(first, labels.GRAPH_FOREIGN);
    branch.* = saved_branch;
    branch.* = primary;
    refused(first, labels.GRAPH_DUPLICATE);
    branch.* = saved_branch;
    const parent = &kagami.tables.walk.getPML4(first.PML4Physical).Entries[decompose.extractPML4Index(inputs.MAP_ADDRESS)];
    const saved_parent = parent.*;
    parent.setPhysicalAddress(first.PML4Physical);
    refused(first, labels.GRAPH_CYCLE);
    parent.* = saved_parent;
    first.TablePages += 1;
    refused(first, labels.GRAPH_COUNT);
    first.TablePages -= 1;
    branch.clear();
    refused(first, labels.GRAPH_ORPHAN);
    branch.* = saved_branch;
    verify.require(kagami.extract.extract(first, inputs.MAP_ADDRESS) == payload and
        kagami.extract.extract(first, inputs.MAP_BRANCH) == payload and
        kagami.extract.extract(second, inputs.MAP_ADDRESS) == payload, labels.GRAPH_RECOVERY);
    verify.require(kagami.destroy.destroy(first) == .Destroyed, labels.GRAPH_RECOVERY);
    live_first = false;
    verify.require(kagami.destroy.destroy(second) == .Destroyed, labels.GRAPH_RECOVERY);
    live_second = false;
    pmm.free.single.freePage(payload);
    live_payload = false;
    budget.clear();
    verify.require(std.meta.eql(before, pmm.state.getStatistics()), labels.GRAPH_RECOVERY);
}

fn refused(root: *Kagami, comptime label: []const u8) void {
    const before = pmm.state.getStatistics();
    const physical = root.PML4Physical;
    const tables = root.TablePages;
    const residents = root.ResidentPages;
    const result = kagami.destroy.destroy(root);
    verify.require(result == .Refused, label);
    verify.require(kagami.create.owns(root) and root.PML4Physical == physical and root.TablePages == tables and
        root.ResidentPages == residents and std.meta.eql(before, pmm.state.getStatistics()), label);
}

fn leafParent(root: *const Kagami, virtual: u64) *Entry {
    const directory = kagami.tables.walk.getPML4(root.PML4Physical).Entries[decompose.extractPML4Index(virtual)].getPhysicalAddress();
    const middle = kagami.tables.walk.getTableFromPhysical(directory).Entries[decompose.extractPDPTIndex(virtual)].getPhysicalAddress();
    return &kagami.tables.walk.getTableFromPhysical(middle).Entries[@intCast((virtual >> indices.PD_SHIFT) & indices.INDEX_MASK)];
}
