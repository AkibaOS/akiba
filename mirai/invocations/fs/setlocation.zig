//! Setlocation invocation - Change current stack location

const afs = @import("../../fs/afs/afs.zig");
const ahci = @import("../../drivers/ahci/ahci.zig");
const copy = @import("../../utils/mem/copy.zig");
const fs_limits = @import("../../common/limits/fs.zig");
const handler = @import("../handler.zig");
const heap = @import("../../memory/heap.zig");
const kata_mod = @import("../../kata/kata.zig");
const location = @import("../../utils/fs/location.zig");
const memory_limits = @import("../../common/limits/memory.zig");
const result = @import("../../utils/types/result.zig");
const sensei = @import("../../kata/sensei/sensei.zig");

var afs_instance: ?*afs.AFS(ahci.BlockDevice) = null;

pub fn set_afs_instance(fs: *afs.AFS(ahci.BlockDevice)) void {
    afs_instance = fs;
}

pub fn invoke(ctx: *handler.InvocationContext) void {
    const fs = afs_instance orelse return result.set_error(ctx);

    const location_ptr = ctx.rdi;
    const location_len = ctx.rsi;

    if (!memory_limits.is_valid_kata_pointer(location_ptr)) return result.set_error(ctx);
    if (location_len > fs_limits.MAX_LOCATION_LENGTH) return result.set_error(ctx);

    const kata = sensei.get_current_kata() orelse return result.set_error(ctx);

    var location_buf: [fs_limits.MAX_LOCATION_LENGTH]u8 = undefined;
    copy.from_ptr(&location_buf, location_ptr, location_len);
    const loc = location_buf[0..location_len];

    const target_cluster = location.resolve_to_cluster(fs, loc, kata.current_cluster) orelse {
        return result.set_error(ctx);
    };

    const canonical = location.canonicalize(kata.current_location[0..kata.current_location_len], loc);

    copy.bytes(kata.current_location[0..canonical.len], canonical.buf[0..canonical.len]);
    kata.current_location_len = canonical.len;
    kata.current_cluster = target_cluster;

    if (kata.parent_id != 0) {
        if (kata_mod.get_kata(kata.parent_id)) |parent| {
            const len: u16 = @intCast(canonical.len);
            if (parent.letter_capacity < len) {
                if (parent.letter_data) |old| {
                    heap.free(@ptrCast(old), parent.letter_capacity);
                }
                const new_buf = heap.alloc(len) orelse return result.set_error(ctx);
                parent.letter_data = new_buf;
                parent.letter_capacity = len;
            }
            parent.letter_type = 1;
            parent.letter_len = len;
            copy.bytes(parent.letter_data.?[0..len], canonical.buf[0..canonical.len]);
        }
    }

    result.set_ok(ctx);
}
