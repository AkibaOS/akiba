//! Spawn invocation - Create new Kata from executable

const afs = @import("../../fs/afs.zig");
const ahci = @import("../../drivers/ahci.zig");
const copy = @import("../../utils/mem/copy.zig");
const fs_limits = @import("../../common/limits/fs.zig");
const handler = @import("../handler.zig");
const hikari = @import("../../hikari/loader.zig");
const kata_limits = @import("../../common/limits/kata.zig");
const memory_limits = @import("../../common/limits/memory.zig");
const result = @import("../../utils/types/result.zig");
const slice = @import("../../utils/mem/slice.zig");

var afs_instance: ?*afs.AFS(ahci.BlockDevice) = null;

pub fn set_afs_instance(fs: *afs.AFS(ahci.BlockDevice)) void {
    afs_instance = fs;
}

pub fn invoke(ctx: *handler.InvocationContext) void {
    const fs = afs_instance orelse return result.set_error(ctx);

    const location_ptr = ctx.rdi;
    const location_len = ctx.rsi;
    const pv_ptr = ctx.rdx;
    const pc = ctx.r10;

    if (!memory_limits.is_valid_kata_pointer(location_ptr)) return result.set_error(ctx);
    if (location_len > fs_limits.MAX_LOCATION_LENGTH) return result.set_error(ctx);

    var location_buf: [fs_limits.MAX_LOCATION_LENGTH]u8 = undefined;
    copy.from_ptr(&location_buf, location_ptr, location_len);
    const location = location_buf[0..location_len];

    var params: [kata_limits.MAX_ARGS][]const u8 = undefined;
    var param_count: usize = 1;
    params[0] = location;

    if (pc > 1 and pv_ptr != 0 and memory_limits.is_valid_kata_pointer(pv_ptr)) {
        const pv = slice.typed_ptr_const(u64, pv_ptr);

        var i: usize = 1;
        while (i < pc and param_count < kata_limits.MAX_ARGS) : (i += 1) {
            const param_ptr = pv[i];
            if (!memory_limits.is_valid_kata_pointer(param_ptr)) break;

            const param_str = slice.null_term_ptr(param_ptr);
            var len: usize = 0;
            while (param_str[len] != 0 and len < kata_limits.MAX_LOCATION_LENGTH) : (len += 1) {}

            params[param_count] = param_str[0..len];
            param_count += 1;
        }
    }

    const kata_id = hikari.load_program_with_args(fs, location, params[0..param_count]) catch {
        return result.set_error(ctx);
    };

    result.set_value(ctx, kata_id);
}
