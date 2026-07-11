//! FAT32 Stack Operations

const types = @import("../types/types.zig");

const StackEntry = types.StackEntry;

pub const LocationError = error{
    NotFound,
    NotAStack,
    InvalidLocation,
};

pub fn identities_equal(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) {
        return false;
    }
    for (a, b) |char_a, char_b| {
        const upper_a = if (char_a >= 'a' and char_a <= 'z') char_a - 32 else char_a;
        const upper_b = if (char_b >= 'a' and char_b <= 'z') char_b - 32 else char_b;
        if (upper_a != upper_b) {
            return false;
        }
    }
    return true;
}

pub const LocationIterator = struct {
    location: []const u8,
    position: usize,

    pub fn init(location: []const u8) LocationIterator {
        var start: usize = 0;
        if (location.len > 0 and (location[0] == '/' or location[0] == '\\')) {
            start = 1;
        }
        return LocationIterator{
            .location = location,
            .position = start,
        };
    }

    pub fn next(self: *LocationIterator) ?[]const u8 {
        while (self.position < self.location.len and
            (self.location[self.position] == '/' or self.location[self.position] == '\\'))
        {
            self.position += 1;
        }

        if (self.position >= self.location.len) {
            return null;
        }

        const start = self.position;
        while (self.position < self.location.len and
            self.location[self.position] != '/' and
            self.location[self.position] != '\\')
        {
            self.position += 1;
        }

        if (self.position == start) {
            return null;
        }

        return self.location[start..self.position];
    }
};

pub fn entry_matches_identity(entry: *const StackEntry, identity: []const u8) bool {
    var short_identity_buf: [12]u8 = undefined;
    const short_identity_len = entry.get_short_identity(&short_identity_buf);
    return identities_equal(short_identity_buf[0..short_identity_len], identity);
}
