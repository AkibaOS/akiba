//! File descriptor utilities

const kata_mod = @import("../kata/kata.zig");
const fd_mod = @import("../kata/fd.zig");
const heap = @import("../memory/heap.zig");
const serial = @import("../drivers/serial.zig");
const afs = @import("../fs/afs.zig");
const ahci = @import("../drivers/ahci.zig");
const path_utils = @import("path.zig");

/// Allocate a free file descriptor (starting from 3)
pub fn allocate_fd(kata: *kata_mod.Kata) !u32 {
    var i: u32 = 3;
    while (i < 16) : (i += 1) {
        if (kata.fd_table[i].fd_type == .Closed) {
            return i;
        }
    }
    return error.TooManyFiles;
}

/// Close a file descriptor, writing back if dirty
pub fn close_fd(kata: *kata_mod.Kata, fd: u32, fs: ?*afs.AFS(ahci.BlockDevice)) void {
    const fd_entry = &kata.fd_table[fd];

    // Write back dirty regular files
    if (fd_entry.fd_type == .Regular and fd_entry.dirty) {
        if (fd_entry.buffer) |buffer| {
            if (fs) |filesystem| {
                const path = fd_entry.path[0..fd_entry.path_len];

                var full_path_buffer: [512]u8 = undefined;
                const full_path = path_utils.resolve_path(kata, path, &full_path_buffer);

                filesystem.write_file(full_path, buffer) catch {
                    serial.print("  Warning: Could not write back file\n");
                };
            }

            // Free buffer
            heap.free(@ptrCast(buffer.ptr), buffer.len);
        }
    }

    // Clear descriptor
    fd_entry.* = fd_mod.FileDescriptor{};
}
