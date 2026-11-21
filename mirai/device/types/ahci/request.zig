//! One Checked AHCI Request

const Operation = @import("shared").ahci.types.command.operation.Operation;

pub const Request = struct {
    Operation: Operation,
    Output: []u8,
};
