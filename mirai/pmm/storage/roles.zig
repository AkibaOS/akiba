//! Two-Bit Physical Page Roles

const geometry = @import("mirai").pmm.constants.storage;
const types = @import("mirai").pmm.types.storage;

pub fn read(view: types.View, page: u64) types.Role {
    const relative = page - view.Range.Start;
    const shift: u3 = @intCast((relative % geometry.PAGES_PER_BYTE) * geometry.ROLE_BITS);
    return @enumFromInt((view.Map[relative / geometry.PAGES_PER_BYTE] >> shift) & geometry.ROLE_MASK);
}

pub fn assign(view: types.View, start: u64, end: u64, role: types.Role) void {
    var relative = start - view.Range.Start;
    const limit = end - view.Range.Start;
    while (relative < limit and relative % geometry.PAGES_PER_BYTE != 0) : (relative += 1) {
        write(view.Map, relative, role);
    }
    const full_bytes_end = limit / geometry.PAGES_PER_BYTE;
    const first_byte = relative / geometry.PAGES_PER_BYTE;
    const pattern = @as(u8, @intFromEnum(role)) * geometry.LOW_ROLE_BITS;
    if (first_byte < full_bytes_end) {
        @memset(view.Map[first_byte..full_bytes_end], pattern);
        relative = full_bytes_end * geometry.PAGES_PER_BYTE;
    }
    while (relative < limit) : (relative += 1) write(view.Map, relative, role);
}

pub fn nextFree(view: types.View, start: u64, end: u64) ?u64 {
    var page = start;
    while (page < end) {
        const relative = page - view.Range.Start;
        const byte = view.Map[relative / geometry.PAGES_PER_BYTE];
        if (relative % geometry.PAGES_PER_BYTE == 0 and end - page >= geometry.PAGES_PER_BYTE and
            ((byte | (byte >> 1)) & geometry.LOW_ROLE_BITS) == geometry.LOW_ROLE_BITS)
        {
            page += geometry.PAGES_PER_BYTE;
        } else if (read(view, page) == .Free) {
            return page;
        } else {
            page += 1;
        }
    }
    return null;
}

pub fn freeEnd(view: types.View, start: u64, end: u64) u64 {
    var page = start;
    while (page < end) {
        const relative = page - view.Range.Start;
        if (relative % geometry.PAGES_PER_BYTE == 0 and end - page >= geometry.PAGES_PER_BYTE and
            view.Map[relative / geometry.PAGES_PER_BYTE] == 0)
        {
            page += geometry.PAGES_PER_BYTE;
        } else if (read(view, page) == .Free) {
            page += 1;
        } else {
            break;
        }
    }
    return page;
}

fn write(map: []u8, relative: u64, role: types.Role) void {
    const shift: u3 = @intCast((relative % geometry.PAGES_PER_BYTE) * geometry.ROLE_BITS);
    const byte = &map[relative / geometry.PAGES_PER_BYTE];
    byte.* = (byte.* & ~(geometry.ROLE_MASK << shift)) | (@as(u8, @intFromEnum(role)) << shift);
}
