//! Run Hikari With The Active EFI Environment

const std = @import("std");

const efi = @import("hikari").efi;
const sequence = @import("hikari").sequence.run;

pub fn run() std.os.uefi.Status {
    const image_handle: efi.types.base.Handle = @ptrCast(std.os.uefi.handle);
    const system_table: *efi.types.services.system.SystemTable = @ptrCast(std.os.uefi.system_table);
    return @enumFromInt(sequence.run(image_handle, system_table));
}
