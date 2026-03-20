//! Release Corpse Resources

const types = @import("../types/types.zig");

const Corpse = types.Corpse;

pub const max_corpses = 16;

var corpse_pool: [max_corpses]Corpse = init_pool();
var corpse_in_use: [max_corpses]bool = [_]bool{false} ** max_corpses;

fn init_pool() [max_corpses]Corpse {
    var pool: [max_corpses]Corpse = undefined;
    for (&pool) |*c| {
        c.clear();
    }
    return pool;
}

pub fn allocate() ?*Corpse {
    for (&corpse_pool, 0..) |*corpse, i| {
        if (!corpse_in_use[i]) {
            corpse_in_use[i] = true;
            corpse.clear();
            return corpse;
        }
    }
    return null;
}

pub fn release(corpse: *Corpse) void {
    for (&corpse_pool, 0..) |*pool_corpse, i| {
        if (pool_corpse == corpse) {
            corpse_in_use[i] = false;
            corpse.clear();
            return;
        }
    }
}

pub fn release_all_for_kata(kata_id: u64) void {
    for (&corpse_pool, 0..) |*corpse, i| {
        if (corpse_in_use[i] and corpse.kata_id == kata_id) {
            corpse_in_use[i] = false;
            corpse.clear();
        }
    }
}

pub fn get_active_count() usize {
    var count: usize = 0;
    for (corpse_in_use) |in_use| {
        if (in_use) count += 1;
    }
    return count;
}
