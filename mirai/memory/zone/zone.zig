//! Zone Allocator

pub const types = @import("types/types.zig");
pub const bootstrap = @import("bootstrap/bootstrap.zig");
pub const create = @import("create/create.zig");
pub const alloc = @import("alloc/alloc.zig");
pub const gc = @import("gc/gc.zig");

pub const Zone = types.Zone;
pub const ZonePageMeta = types.ZonePageMeta;

pub const init = bootstrap.init;
pub const zone_create = create.create;
pub const zalloc = alloc.zalloc;
pub const zalloc_zeroed = alloc.zalloc_zeroed;
pub const zfree = alloc.zfree;
pub const collect = gc.collect;

pub const AllocError = alloc.AllocError;
pub const CreateError = create.CreateError;
