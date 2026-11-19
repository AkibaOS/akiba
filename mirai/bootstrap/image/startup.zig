//! Initialize And Seal Child-Owned Startup Data

const std = @import("std");

const common = @import("common");
const types = @import("mirai").bootstrap.types.image;
const user = @import("mirai").user;
const wire = @import("mirai").bootstrap.constants.startup;

const ImageError = @import("mirai").bootstrap.errors.image.ImageError;
const Kata = @import("mirai").kata.types.kata.Kata;
const sizes = common.constants.memory.sizes;
const address = common.constants.memory.layout;

pub fn pageBytes(source: types.Startup) ImageError!u64 {
    if (source.Identity.len == 0) return ImageError.InvalidStartup;
    const metadata = std.math.add(u64, wire.HEADER_BYTES, source.Identity.len) catch return ImageError.NoStartupSpace;
    const length = std.math.add(u64, metadata, source.Parameters.len) catch return ImageError.NoStartupSpace;
    if (length > address.USER_SPACE_END + 1 - sizes.PAGE_SIZE) return ImageError.NoStartupSpace;
    return (length + sizes.PAGE_MASK) & ~sizes.PAGE_MASK;
}

pub fn install(owner: *Kata, span: types.StartupSpan, source: types.Startup) ImageError!void {
    var page = span.Start;
    while (page < span.End) : (page += sizes.PAGE_SIZE) try user.memory.allocate.allocate(owner, page);

    var header: [wire.HEADER_BYTES]u8 = undefined;
    std.mem.writeInt(u64, header[0..wire.IDENTITY_LENGTH], wire.VERSION, .little);
    std.mem.writeInt(u64, header[wire.IDENTITY_LENGTH..wire.PARAMETER_LENGTH], source.Identity.len, .little);
    std.mem.writeInt(u64, header[wire.PARAMETER_LENGTH..], source.Parameters.len, .little);
    const identity = span.Start + wire.HEADER_BYTES;
    try copy(owner, span.Start, &header);
    try copy(owner, identity, source.Identity);
    try copy(owner, identity + source.Identity.len, source.Parameters);

    page = span.Start;
    while (page < span.End) : (page += sizes.PAGE_SIZE) try user.memory.finalize.finalize(owner, page, .ReadOnly);
}

pub fn validate(owner: *const Kata, base: u64) ImageError!void {
    const limit = address.USER_SPACE_END + 1;
    if (base < sizes.PAGE_SIZE or base >= limit or base % sizes.PAGE_SIZE != 0) return ImageError.InvalidStartup;
    var header: [wire.HEADER_BYTES]u8 = undefined;
    try user.copy.transfer.read(owner, &header, base);
    const identity = std.mem.readInt(u64, header[wire.IDENTITY_LENGTH..wire.PARAMETER_LENGTH], .little);
    const parameters = std.mem.readInt(u64, header[wire.PARAMETER_LENGTH..], .little);
    if (std.mem.readInt(u64, header[0..wire.IDENTITY_LENGTH], .little) != wire.VERSION or identity == 0)
        return ImageError.InvalidStartup;
    const prefix = std.math.add(u64, wire.HEADER_BYTES, identity) catch return ImageError.InvalidStartup;
    const length = std.math.add(u64, prefix, parameters) catch return ImageError.InvalidStartup;
    if (length > limit - base) return ImageError.InvalidStartup;
    const end = (base + length + sizes.PAGE_MASK) & ~sizes.PAGE_MASK;
    var page = base;
    while (page < end) : (page += sizes.PAGE_SIZE) {
        const record = user.state.ledger.find(owner, page) orelse return ImageError.InvalidStartup;
        if (record.Backing.Stage != .ReadOnly) return ImageError.InvalidStartup;
        try user.state.access.validate(record, false);
    }
}

fn copy(owner: *Kata, base: u64, bytes: []const u8) ImageError!void {
    var offset: usize = 0;
    while (offset < bytes.len) {
        const count = @min(bytes.len - offset, user.constants.limits.MAX_COPY_BYTES);
        try user.memory.load.load(owner, base + offset, bytes[offset..][0..count]);
        offset += count;
    }
}
