//! Effective Mapping Address And Permission Queries

const create = @import("mirai").kagami.create;
const guard = @import("asm").interrupts.guard;
const state = @import("mirai").kagami.state;
const tables = @import("mirai").kagami.tables;
const types = @import("mirai").kagami.types;

const Kagami = types.kagami.Kagami;
const Lookup = types.lookup.Lookup;

pub fn lookup(kagami: *const Kagami, virtual_address: u64) ?Lookup {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!state.hasOwnedKernel() or
        !(kagami.isKernel() or create.owns(kagami))) return null;
    return tables.walk.lookup(kagami.PML4Physical, virtual_address);
}

pub fn extract(kagami: *const Kagami, virtual_address: u64) ?u64 {
    const resolved = lookup(kagami, virtual_address) orelse return null;
    return resolved.PhysicalAddress;
}

pub fn isMapped(kagami: *const Kagami, virtual_address: u64) bool {
    return lookup(kagami, virtual_address) != null;
}

pub fn isWritable(kagami: *const Kagami, virtual_address: u64) bool {
    const resolved = lookup(kagami, virtual_address) orelse return false;
    return resolved.Writable;
}

pub fn isUserAccessible(kagami: *const Kagami, virtual_address: u64) bool {
    const resolved = lookup(kagami, virtual_address) orelse return false;
    return resolved.UserAccessible;
}

pub fn isExecutable(kagami: *const Kagami, virtual_address: u64) bool {
    const resolved = lookup(kagami, virtual_address) orelse return false;
    return resolved.Executable;
}
