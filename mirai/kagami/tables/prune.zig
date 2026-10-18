//! Empty Owned Table Reclamation

const allocate = @import("mirai").kagami.tables.allocate;
const common = @import("common");
const constants = @import("mirai").kagami.constants.bootstrap;
const cpu = @import("asm").cpu;
const guard = @import("asm").interrupts.guard;
const policy = @import("mirai").kagami.policy;
const types = @import("mirai").kagami.types;
const walk = @import("mirai").kagami.tables.walk;

const indices = common.constants.paging.indices;
const Entry = types.entry.Entry;
const Kagami = types.kagami.Kagami;

pub fn prune(kagami: *Kagami, virtual_address: u64) void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    policy.canMutate(kagami, virtual_address) catch return;
    var parents: [constants.MAX_INTERMEDIATE_TABLES]*Entry = undefined;
    var children: [constants.MAX_INTERMEDIATE_TABLES]u64 = undefined;
    var physical_address = kagami.PML4Physical;
    const shifts = [_]u6{ indices.PML4_SHIFT, indices.PDPT_SHIFT, indices.PD_SHIFT };
    for (shifts, 0..) |shift, level| {
        if (!walk.isValidTable(physical_address)) return;
        const table = walk.getTableFromPhysical(physical_address);
        const parent = &table.Entries[@intCast((virtual_address >> shift) & indices.INDEX_MASK)];
        if (!parent.Present or parent.HugePage or !parent.isOwnedTable()) return;
        const child = parent.getPhysicalAddress();
        if (!walk.isValidTable(child) or child == kagami.PML4Physical) return;
        for (children[0..level]) |ancestor| {
            if (child == ancestor) return;
        }
        parents[level] = parent;
        children[level] = child;
        physical_address = child;
    }
    var depth: usize = shifts.len;
    while (depth != 0) {
        depth -= 1;
        if (depth == 0 and kagami.Ownership == .Kernel) break;
        if (walk.getTableFromPhysical(children[depth]).countPresent() != 0) break;
        parents[depth].clear();
        cpu.control.flushAllTLB();
        allocate.freeTable(children[depth]);
        kagami.removeTable();
    }
}
