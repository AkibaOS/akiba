//! Attachment utilities

const afs = @import("../../fs/afs/afs.zig");
const ahci = @import("../../drivers/ahci/ahci.zig");
const attachment = @import("../../kata/attachment.zig");
const fd_mod = @import("../../kata/attachment.zig");
const heap = @import("../../memory/heap.zig");
const kata_limits = @import("../../common/limits/kata.zig");
const kata_mod = @import("../../kata/kata.zig");
const path = @import("../fs/path.zig");

pub fn allocate(kata: *kata_mod.Kata) !u32 {
    var i: u32 = 3;
    while (i < kata_limits.MAX_ATTACHMENTS) : (i += 1) {
        if (kata.attachments[i].attachment_type == .Closed) {
            return i;
        }
    }
    return error.TooManyAttachments;
}

pub fn seal(kata: *kata_mod.Kata, fd: u32, fs: ?*afs.AFS(ahci.BlockDevice)) void {
    const entry = &kata.attachments[fd];

    if (entry.attachment_type == .Unit and entry.dirty) {
        if (entry.buffer) |buffer| {
            if (fs) |filesystem| {
                var full_location_buf: [512]u8 = undefined;
                const full_location = path.resolve(kata, entry.path[0..entry.path_len], &full_location_buf);
                filesystem.mark_unit(full_location, buffer) catch {};
            }
            heap.free(@ptrCast(buffer.ptr), buffer.len);
        }
    }

    entry.* = attachment.Attachment{};
}
