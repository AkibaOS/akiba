//! Read The Supervisor Identity From A Native Startup Record

const std = @import("std");

const layout = @import("sdk").persona.constants.startup.record;

pub fn supervisor(address: u64) !u64 {
    if (address == 0 or address > std.math.maxInt(usize) - layout.HEADER_BYTES) return error.InvalidStartup;
    const bytes: [*]const u8 = @ptrFromInt(address);
    if (std.mem.readInt(u64, bytes[0..layout.IDENTITY_LENGTH], .little) != layout.VERSION) return error.InvalidStartup;
    const identity = std.mem.readInt(u64, bytes[layout.IDENTITY_LENGTH..layout.PARAMETER_LENGTH], .little);
    const parameters = std.mem.readInt(u64, bytes[layout.PARAMETER_LENGTH..layout.HEADER_BYTES], .little);
    if (identity == 0 or parameters < @sizeOf(u64)) return error.InvalidStartup;
    const payload = std.math.add(u64, layout.HEADER_BYTES, identity) catch return error.InvalidStartup;
    const pointer = std.math.add(u64, address, payload) catch return error.InvalidStartup;
    if (pointer > std.math.maxInt(usize) - @sizeOf(u64)) return error.InvalidStartup;
    const owner = std.mem.readInt(u64, bytes[payload..][0..@sizeOf(u64)], .little);
    return if (owner == 0) error.InvalidStartup else owner;
}
