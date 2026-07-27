//! Release Corpse Resources

const constants = @import("../constants/constants.zig");
const types = @import("../types/types.zig");

const limits = constants.limits;

const Corpse = types.corpse.Corpse;

var corpse_pool: [limits.MAX_CORPSES]Corpse = initPool();
var corpse_in_use: [limits.MAX_CORPSES]bool = [_]bool{false} ** limits.MAX_CORPSES;

fn initPool() [limits.MAX_CORPSES]Corpse {
    var pool: [limits.MAX_CORPSES]Corpse = undefined;
    for (&pool) |*corpse| {
        corpse.clear();
    }
    return pool;
}

pub fn allocate() ?*Corpse {
    for (&corpse_pool, 0..) |*corpse, index| {
        if (!corpse_in_use[index]) {
            corpse_in_use[index] = true;
            corpse.clear();
            return corpse;
        }
    }
    return null;
}

pub fn release(corpse: *Corpse) void {
    for (&corpse_pool, 0..) |*pool_corpse, index| {
        if (pool_corpse == corpse) {
            corpse_in_use[index] = false;
            corpse.clear();
            return;
        }
    }
}

pub fn releaseAllForKata(kata_id: u64) void {
    for (&corpse_pool, 0..) |*corpse, index| {
        if (corpse_in_use[index] and corpse.KataId == kata_id) {
            corpse_in_use[index] = false;
            corpse.clear();
        }
    }
}

pub fn getActiveCount() usize {
    var count: usize = 0;
    for (corpse_in_use) |in_use| {
        if (in_use) count += 1;
    }
    return count;
}
