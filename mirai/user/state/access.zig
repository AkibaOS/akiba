//! Exact Owned User Page Access

const checks = @import("mirai").user.state.checks;
const common = @import("common");
const protection = @import("mirai").kagami.constants.protection;
const types = @import("mirai").user.types;
const usererrors = @import("mirai").user.errors.memory.mappings;

const sizes = common.constants.memory.sizes;
const Backing = types.backing.Backing;
const Lookup = @import("mirai").kagami.types.lookup.Lookup;
const Record = types.record.Record;
const Stage = types.stage.Stage;
const UserError = usererrors.UserError;

pub fn isWritable(stage: Stage) bool {
    return stage == .Loading or stage == .Writable;
}

pub fn isExecutable(stage: Stage) bool {
    return stage == .Executable;
}

pub fn permissions(stage: Stage) u8 {
    return switch (stage) {
        .Loading, .Writable => protection.USER_WRITE,
        .ReadOnly => protection.USER_READ,
        .Executable => protection.USER_EXECUTE,
    };
}

pub fn validate(record: *const Record, write_access: bool) UserError!void {
    const resolved = checks.lookupOwned(record) orelse return UserError.InvalidOwnedMapping;
    const writable = isWritable(record.Backing.Stage);
    const executable = isExecutable(record.Backing.Stage);
    if (write_access and !writable) return UserError.SealedPage;
    if (resolved.Writable != writable or resolved.Entry.Writable != writable or
        resolved.Executable != executable or resolved.Entry.NoExecute == executable) return UserError.InvalidOwnedMapping;
    const alias = checks.lookupAlias(record) orelse return UserError.InvalidPhysmap;
    if (alias.Writable != writable or alias.Entry.Writable != writable or
        (!writable and alias.PageSize != sizes.PAGE_SIZE)) return UserError.InvalidPhysmap;
}

pub fn sealedAlias(frame: *const Backing) UserError!Lookup {
    const alias = checks.lookupBackingAlias(frame) orelse return UserError.InvalidPhysmap;
    if (isWritable(frame.Stage)) return UserError.NotShareable;
    if (alias.Writable or alias.Entry.Writable or alias.PageSize != sizes.PAGE_SIZE) return UserError.InvalidPhysmap;
    return alias;
}
