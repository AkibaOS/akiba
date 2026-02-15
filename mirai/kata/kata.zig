//! Kata - Process management

pub const types = @import("types.zig");
pub const pool = @import("pool.zig");
pub const attachment = @import("attachment.zig");
pub const memory = @import("memory.zig");
pub const sensei = @import("sensei/sensei.zig");
pub const shift = @import("shift.zig");

pub const Kata = types.Kata;
pub const Context = types.Context;
pub const State = types.State;
pub const InterruptContext = types.InterruptContext;

pub const Attachment = attachment.Attachment;
pub const AttachmentType = attachment.Type;
pub const DeviceType = attachment.DeviceType;

pub const init = pool.init;
pub const create_kata = pool.create;
pub const get_kata = pool.get;
pub const dissolve_kata = pool.dissolve;

pub const kata_pool = pool.pool;
pub const kata_used = pool.used;

pub const setup_kata_memory = memory.setup;
pub const load_segment = memory.load_segment;
pub const VirtualBuffer = memory.VirtualBuffer;
