//! Reap invocation - Shinigami cleans up zombie katas

const handler = @import("../handler.zig");
const memory = @import("../../kata/memory.zig");
const paging_const = @import("../../common/constants/paging.zig");
const pool = @import("../../kata/pool.zig");
const serial = @import("../../drivers/serial/serial.zig");
const types = @import("../../kata/types.zig");

const HIGHER_HALF: u64 = 0xFFFF800000000000;

fn check_ash_pd256() u64 {
    for (&pool.pool, 0..) |*k, i| {
        if (pool.used[i] and k.id == 3 and k.page_table != 0) {
            const pml4: [*]volatile u64 = @ptrFromInt(k.page_table + HIGHER_HALF);
            if ((pml4[0] & 1) == 0) return 0xDEAD0001;
            const pdpt: [*]volatile u64 = @ptrFromInt((pml4[0] & paging_const.PTE_MASK) + HIGHER_HALF);
            if ((pdpt[0] & 1) == 0) return 0xDEAD0002;
            const pd: [*]volatile u64 = @ptrFromInt((pdpt[0] & paging_const.PTE_MASK) + HIGHER_HALF);
            return pd[256];
        }
    }
    return 0xDEAD0000;
}

/// Reap zombie katas - called by Shinigami
/// Returns the number of zombies reaped
pub fn invoke(ctx: *handler.InvocationContext) void {
    var reaped: u64 = 0;

    for (&pool.pool, 0..) |*kata, i| {
        if (!pool.used[i]) continue;
        if (kata.state != .Zombie) continue;

        // Found a zombie - reap it
        const kata_id = kata.id;
        const pt = kata.page_table;

        const pd256_before = check_ash_pd256();
        serial.printf("Shinigami: reaping kata {d} pt={x} ash_pd256={x}\n", .{ kata_id, pt, pd256_before });

        // Destroy the page table
        if (kata.page_table != 0) {
            memory.destroy_zombie_page_table(kata.page_table);
            kata.page_table = 0;
        }

        const pd256_after = check_ash_pd256();
        if (pd256_after != pd256_before) {
            serial.printf("Shinigami: CORRUPTION during reap! pd256: {x} -> {x}\n", .{ pd256_before, pd256_after });
        }

        // Mark as dissolved and free the slot
        kata.state = .Dissolved;
        pool.used[i] = false;

        serial.printf("Shinigami: reaped kata {d}\n", .{kata_id});
        reaped += 1;
    }

    ctx.rax = reaped;
}
