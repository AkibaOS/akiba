//! Viewstack invocation - List contents of a stack

const afs = @import("../../fs/afs/afs.zig");
const ahci = @import("../../drivers/ahci/ahci.zig");
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

const MAX_ENTRY_IDENTITY: usize = 64;
const MAX_ENTRY_OWNER: usize = 64;

const UserStackEntry = extern struct {
    identity: [MAX_ENTRY_IDENTITY]u8,
    identity_len: u8,
    is_stack: bool,
    owner_name_len: u8,
    permission_type: u8,
    size: u32,
    modified_time: u64,
    owner_name: [MAX_ENTRY_OWNER]u8,
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

    var items: [fs_limits.MAX_STACK_ITEMS]afs.StackItem = undefined;
    const item_count = fs.list_stack(target_cluster, &items) catch return result.set_error(ctx);

    const user_entries = slice.typed_ptr(UserStackEntry, entries_ptr);
    const copy_count = @min(item_count, max_entries);

    for (0..copy_count) |i| {
        const item = &items[i];
        var user_entry = &user_entries[i];

        const identity = item.get_identity();
        const id_len = @min(identity.len, MAX_ENTRY_IDENTITY - 1);
        copy.bytes(user_entry.identity[0..id_len], identity[0..id_len]);
        user_entry.identity_len = @intCast(id_len);
        user_entry.size = item.size;
        user_entry.is_stack = item.is_stack;
        user_entry.modified_time = item.modified_time;

        const owner = item.get_owner();
        const owner_len = @min(owner.len, MAX_ENTRY_OWNER - 1);
        copy.bytes(user_entry.owner_name[0..owner_len], owner[0..owner_len]);
        user_entry.owner_name_len = @intCast(owner_len);
        user_entry.permission_type = item.permission_type;
    }

    result.set_value(ctx, copy_count);
}
