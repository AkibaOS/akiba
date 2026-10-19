//! Owned User Frame Mapping Permissions

const checks = @import("mirai").user.state.checks;
const kagami = @import("mirai").kagami;
const ledger = @import("mirai").user.state.ledger;
const limits = @import("mirai").user.constants.limits;
const types = @import("mirai").user.types;

const protection = kagami.constants.protection;
const Kagami = kagami.types.kagami.Kagami;
const Record = types.record.Record;

pub fn permitsMapping(root: *const Kagami, virtual_address: u64, physical_address: u64, permissions: u8) bool {
    var index: usize = 0;
    while (index < limits.MAX_OWNED_PAGES) : (index += 1) {
        const record = ledger.at(index) orelse continue;
        const exact = record.Owner.AddressSpace == root and record.VA == virtual_address;
        if (exact) return record.PA == physical_address and permitsOwned(record, permissions);
        if (record.PA == physical_address) return false;
    }
    return true;
}

pub fn permitsRemoval(root: *const Kagami, virtual_address: u64, physical_address: u64) bool {
    if (root == kagami.state.getCurrentKagami() or kagami.activate.isActive(root) or
        root.ExecutionOwners != 1 or root.ReferenceCount != 1) return false;
    var index: usize = 0;
    while (index < limits.MAX_OWNED_PAGES) : (index += 1) {
        const record = ledger.at(index) orelse continue;
        if (record.Owner.AddressSpace != root or record.VA != virtual_address) continue;
        return record.PA == physical_address and checks.isValidOwner(record.Owner) and
            record.Owner.ThreadCount == 0 and checks.lookupOwned(record) != null;
    }
    return false;
}

fn permitsOwned(record: *const Record, permissions: u8) bool {
    if (!checks.isValidOwner(record.Owner) or
        (permissions & protection.USER) == 0 or (permissions & protection.NOCACHE) != 0) return false;
    const writable = (permissions & protection.WRITE) != 0;
    const executable = (permissions & protection.EXECUTE) != 0;
    return switch (record.Stage) {
        .Loading => !executable,
        .Sealed => !writable,
    };
}
