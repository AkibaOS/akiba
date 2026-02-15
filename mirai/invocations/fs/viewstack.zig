//! Viewstack invocation - List contents of a stack

const afs = @import("../../fs/afs.zig");
const ahci = @import("../../drivers/ahci.zig");
const copy = @import("../../utils/mem/copy.zig");
const fs_limits = @import("../../common/limits/fs.zig");
const handler = @import("../handler.zig");
const int = @import("../../utils/types/int.zig");
const location = @import("../../utils/fs/location.zig");
const memory_limits = @import("../../common/limits/memory.zig");
const ptr = @import("../../utils/types/ptr.zig");
const result = @import("../../utils/types/result.zig");
const sensei = @import("../../kata/sensei.zig");
const slice = @import("../../utils/mem/slice.zig");

const StackEntry = extern struct {
    identity: [64]u8,
    identity_len: u8,
    is_stack: bool,
    owner_name_len: u8,
    permission_type: u8,
    size: u32,
    modified_time: u64,
    owner_name: [64]u8,
};

var afs_instance: ?*afs.AFS(ahci.BlockDevice) = null;

pub fn set_afs_instance(fs: *afs.AFS(ahci.BlockDevice)) void {
    afs_instance = fs;
}

pub fn invoke(ctx: *handler.InvocationContext) void {
    const fs = afs_instance orelse return result.set_error(ctx);

    const location_ptr = ctx.rdi;
    const location_len = ctx.rsi;
    const entries_ptr = ctx.rdx;
    const max_entries = ctx.r10;

    if (!memory_limits.is_valid_kata_pointer(location_ptr) or !memory_limits.is_valid_kata_pointer(entries_ptr)) {
        return result.set_error(ctx);
    }

    if (location_len > fs_limits.MAX_LOCATION_LENGTH) return result.set_error(ctx);

    var location_buf: [fs_limits.MAX_LOCATION_LENGTH]u8 = undefined;
    copy.from_ptr(&location_buf, location_ptr, location_len);
    const loc = location_buf[0..location_len];

    const kata = sensei.get_current_kata();
    const current_cluster: u64 = if (kata) |k| k.current_cluster else 0;

    const target_cluster = location.resolve_to_cluster(fs, loc, current_cluster) orelse {
        return result.set_error(ctx);
    };

    var mirai_entries: [32]afs.ListEntry = undefined;
    const entry_count = fs.list_directory(target_cluster, &mirai_entries) catch return result.set_error(ctx);

    const kata_entries = slice.typed_ptr(StackEntry, entries_ptr);
    const copy_count = @min(entry_count, max_entries);

    for (0..copy_count) |i| {
        const entry = &mirai_entries[i];
        var kata_entry = &kata_entries[i];

        const name_len = @min(entry.name_len, 63);
        copy.bytes(kata_entry.identity[0..name_len], entry.name[0..name_len]);
        kata_entry.identity_len = int.u8_of(name_len);
        kata_entry.size = entry.file_size;
        kata_entry.is_stack = entry.is_directory;
        kata_entry.modified_time = entry.modified_time;

        const owner_len = @min(entry.owner_name_len, 63);
        copy.bytes(kata_entry.owner_name[0..owner_len], entry.owner_name[0..owner_len]);
        kata_entry.owner_name_len = int.u8_of(owner_len);
        kata_entry.permission_type = entry.permission_type;
    }

    result.set_value(ctx, copy_count);
}
