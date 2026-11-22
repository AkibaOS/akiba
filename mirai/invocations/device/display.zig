//! Copy Assigned Surface Mode And Row Invocation Data

const std = @import("std");

const copy = @import("mirai").user.copy.transfer;
const surface = @import("mirai").device.display.frame;

const Operation = @import("shared").device.types.operation.Operation;
const Row = @import("shared").display.types.row.Row;
const Thread = @import("mirai").thread.types.thread.Thread;

pub fn perform(caller: *Thread, operation: Operation, handle: u64, address: u64) !void {
    try surface.check(caller, handle);
    switch (operation) {
        .SurfaceDescribe => {
            const mode = try surface.mode(caller, handle);
            try copy.write(caller.Owner, address, std.mem.asBytes(&mode));
        },
        .SurfaceRow => {
            var row: Row = undefined;
            try copy.read(caller.Owner, std.mem.asBytes(&row), address);
            try surface.present(caller, handle, row);
        },
        else => return error.InvalidArgument,
    }
}
