//! Owned User Frame Mapping Permissions

const access = @import("mirai").user.state.access;
const checks = @import("mirai").user.state.checks;
const kagami = @import("mirai").kagami;
const ledger = @import("mirai").user.state.ledger;
const types = @import("mirai").user.types;

const protection = kagami.constants.protection;
const Kagami = kagami.types.kagami.Kagami;
const Record = types.record.Record;

pub fn permitsMapping(root: *const Kagami, virtual_address: u64, physical_address: u64, permissions: u8) bool {
    if (ledger.findRoot(root, virtual_address)) |record|
        return record.PA == physical_address and permitsOwned(record, permissions);
    return !ledger.ownsPhysical(physical_address);
}

pub fn permitsRemoval(root: *const Kagami, virtual_address: u64, physical_address: u64) bool {
    if (!kagami.create.owns(root)) return false;
    if (root == kagami.state.getCurrentKagami() or kagami.activate.isActive(root) or
        root.ExecutionOwners != 1 or root.ReferenceCount != 1) return false;
    const record = ledger.findRoot(root, virtual_address) orelse return false;
    return record.PA == physical_address and checks.isValidOwner(record.Owner) and
        record.Owner.ThreadCount == 0 and checks.lookupOwned(record) != null;
}

fn permitsOwned(record: *const Record, permissions: u8) bool {
    if (!checks.isValidOwner(record.Owner) or record.Owner.State == .Dead or
        (permissions & protection.USER) == 0 or (permissions & protection.NOCACHE) != 0) return false;
    const writable = (permissions & protection.WRITE) != 0;
    const executable = (permissions & protection.EXECUTE) != 0;
    return writable == access.isWritable(record.Stage) and executable == access.isExecutable(record.Stage);
}
