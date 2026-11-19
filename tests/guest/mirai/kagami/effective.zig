//! Inactive Root Effective Parent Rights And Huge Offsets

const common = @import("common");
const decompose = @import("utils").address.decompose;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").guest.constants.memory;
const kagami = @import("mirai").kagami;
const labels = @import("tests").guest.strings.memory;
const pmm = @import("mirai").pmm;
const verify = @import("tests").guest.support.verify;

const Entry = kagami.types.entry.Entry;
const sizes = common.constants.memory.sizes;
const walk = kagami.tables.walk;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const physical = try pmm.allocate.single.allocatePageZeroed();
    defer pmm.free.single.freePage(physical);
    const root = try kagami.create.create();
    defer _ = kagami.destroy.destroy(root);
    try kagami.enter.enter(root, inputs.MAP_ADDRESS, physical, kagami.constants.protection.USER_WRITE);
    const first = &walk.getPML4(root.PML4Physical).Entries[decompose.extractPML4Index(inputs.MAP_ADDRESS)];
    const second = &walk.getTableFromPhysical(first.getPhysicalAddress()).Entries[decompose.extractPDPTIndex(inputs.MAP_ADDRESS)];
    const third = &walk.getTableFromPhysical(second.getPhysicalAddress()).Entries[decompose.extractPDIndex(inputs.MAP_ADDRESS)];
    const leaf = &walk.getTableFromPhysical(third.getPhysicalAddress()).Entries[decompose.extractPTIndex(inputs.MAP_ADDRESS)];
    const parents = [_]*Entry{ first, second, third };
    const saved = [_]Entry{ first.*, second.*, third.* };
    const saved_leaf = leaf.*;
    defer {
        for (parents, saved) |parent, original| parent.* = original;
        leaf.* = saved_leaf;
    }
    leaf.Writable = true;
    leaf.UserAccessible = true;
    leaf.NoExecute = false;
    const initial = walk.lookup(root.PML4Physical, inputs.MAP_ADDRESS).?;
    verify.require(!kagami.activate.isActive(root) and initial.Writable and initial.UserAccessible and initial.Executable, labels.PARENT_FIXTURE);
    for (parents, saved) |parent, original| {
        parent.Writable = false;
        const readonly = walk.lookup(root.PML4Physical, inputs.MAP_ADDRESS).?;
        verify.require(!readonly.Writable and readonly.UserAccessible and readonly.Executable and leaf.Writable, labels.PARENT_WRITE);
        parent.* = original;
        parent.UserAccessible = false;
        const supervisor = walk.lookup(root.PML4Physical, inputs.MAP_ADDRESS).?;
        verify.require(supervisor.Writable and !supervisor.UserAccessible and supervisor.Executable and leaf.UserAccessible, labels.PARENT_USER);
        parent.* = original;
        parent.NoExecute = true;
        const nx = walk.lookup(root.PML4Physical, inputs.MAP_ADDRESS).?;
        verify.require(nx.Writable and nx.UserAccessible and !nx.Executable and !leaf.NoExecute, labels.PARENT_EXECUTE);
        parent.* = original;
    }
    third.HugePage = true;
    third.AvailableLow = 0;
    third.setPhysicalAddress(sizes.LARGE_PAGE_SIZE);
    const huge = walk.lookup(root.PML4Physical, inputs.MAP_ADDRESS + inputs.HUGE_LOOKUP_OFFSET).?;
    verify.require(huge.Entry == third and huge.PageSize == sizes.LARGE_PAGE_SIZE and
        huge.PhysicalAddress == sizes.LARGE_PAGE_SIZE + inputs.HUGE_LOOKUP_OFFSET and
        huge.Writable and huge.UserAccessible and huge.Executable, labels.HUGE_OFFSET);
}
