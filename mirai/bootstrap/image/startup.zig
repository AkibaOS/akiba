//! Initialize And Seal Child-Owned Startup Data

const codec = @import("shared").launch.startup;
const common = @import("common");
const types = @import("mirai").bootstrap.types.image.preparation;
const user = @import("mirai").user;
const wire = @import("shared").launch.constants.startup;

const ImageError = @import("mirai").bootstrap.errors.image.preparation.ImageError;
const Kata = @import("mirai").kata.types.kata.Kata;
const sizes = common.constants.memory.sizes;
const address = common.constants.memory.layout;

pub fn pageBytes(source: types.Startup) ImageError!u64 {
    return codec.size(source.Identity.len, source.Parameters.len, address.USER_SPACE_END + 1 - sizes.PAGE_SIZE);
}

pub fn install(owner: *Kata, span: types.StartupSpan, source: types.Startup) ImageError!void {
    var page = span.Start;
    while (page < span.End) : (page += sizes.PAGE_SIZE) try user.memory.allocate.allocate(owner, page);

    const header = codec.encode(source.Identity.len, source.Parameters.len);
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
    const extent = codec.decode(&header, limit - base) catch return ImageError.InvalidStartup;
    const end = base + extent;
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
