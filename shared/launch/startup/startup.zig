//! Encode And Bound The Private Startup Record

const std = @import("std");

const address_space = @import("common").constants.memory.layout;
const layout = @import("shared").launch.constants.startup.record;
const sizes = @import("common").constants.memory.sizes;

const StartupError = @import("shared").launch.errors.startup.codec.StartupError;

pub fn size(identity: u64, parameters: u64, available: u64) StartupError!u64 {
    if (identity == 0) return error.InvalidStartup;
    const prefix = std.math.add(u64, layout.HEADER_BYTES, identity) catch return error.NoStartupSpace;
    const length = std.math.add(u64, prefix, parameters) catch return error.NoStartupSpace;
    const aligned = std.math.add(u64, length, sizes.PAGE_MASK) catch return error.NoStartupSpace;
    const extent = aligned & ~sizes.PAGE_MASK;
    if (extent > available) return error.NoStartupSpace;
    return extent;
}

pub fn encode(identity: u64, parameters: u64) [layout.HEADER_BYTES]u8 {
    var bytes: [layout.HEADER_BYTES]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..layout.IDENTITY_LENGTH], layout.VERSION, .little);
    std.mem.writeInt(u64, bytes[layout.IDENTITY_LENGTH..layout.PARAMETER_LENGTH], identity, .little);
    std.mem.writeInt(u64, bytes[layout.PARAMETER_LENGTH..], parameters, .little);
    return bytes;
}

pub fn decode(bytes: *const [layout.HEADER_BYTES]u8, available: u64) StartupError!u64 {
    if (std.mem.readInt(u64, bytes[0..layout.IDENTITY_LENGTH], .little) != layout.VERSION) return error.InvalidStartup;
    const identity = std.mem.readInt(u64, bytes[layout.IDENTITY_LENGTH..layout.PARAMETER_LENGTH], .little);
    const parameters = std.mem.readInt(u64, bytes[layout.PARAMETER_LENGTH..], .little);
    return size(identity, parameters, available);
}

pub fn supervisor(address: u64) StartupError!u64 {
    const limit = address_space.USER_SPACE_END + 1;
    if (address < sizes.PAGE_SIZE or address % sizes.PAGE_SIZE != 0 or address > limit - sizes.PAGE_SIZE)
        return error.InvalidStartup;
    const bytes: [*]const u8 = @ptrFromInt(address);
    _ = try decode(bytes[0..layout.HEADER_BYTES], limit - address);
    const identity = std.mem.readInt(u64, bytes[layout.IDENTITY_LENGTH..layout.PARAMETER_LENGTH], .little);
    const parameters = std.mem.readInt(u64, bytes[layout.PARAMETER_LENGTH..layout.HEADER_BYTES], .little);
    if (parameters < @sizeOf(u64)) return error.InvalidStartup;
    const owner = std.mem.readInt(u64, bytes[layout.HEADER_BYTES + identity ..][0..@sizeOf(u64)], .little);
    if (owner == 0) return error.InvalidStartup;
    return owner;
}
