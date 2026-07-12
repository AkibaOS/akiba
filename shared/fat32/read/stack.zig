//! FAT32 Stack Operations

const constants = @import("../constants/constants.zig");
const types = @import("../types/types.zig");

const StackEntry = types.entry.StackEntry;

pub fn identitiesEqual(left: []const u8, right: []const u8) bool {
    if (left.len != right.len) {
        return false;
    }
    for (left, right) |left_char, right_char| {
        const upper_left = if (left_char >= 'a' and left_char <= 'z') left_char - ('a' - 'A') else left_char;
        const upper_right = if (right_char >= 'a' and right_char <= 'z') right_char - ('a' - 'A') else right_char;
        if (upper_left != upper_right) {
            return false;
        }
    }
    return true;
}

pub const LocationIterator = struct {
    Location: []const u8,
    Position: usize,

    pub fn init(location: []const u8) LocationIterator {
        var start: usize = 0;
        if (location.len > 0 and (location[0] == '/' or location[0] == '\\')) {
            start = 1;
        }
        return LocationIterator{
            .Location = location,
            .Position = start,
        };
    }

    pub fn next(self: *LocationIterator) ?[]const u8 {
        while (self.Position < self.Location.len and
            (self.Location[self.Position] == '/' or self.Location[self.Position] == '\\'))
        {
            self.Position += 1;
        }

        if (self.Position >= self.Location.len) {
            return null;
        }

        const start = self.Position;
        while (self.Position < self.Location.len and
            self.Location[self.Position] != '/' and
            self.Location[self.Position] != '\\')
        {
            self.Position += 1;
        }

        if (self.Position == start) {
            return null;
        }

        return self.Location[start..self.Position];
    }
};

pub fn entryMatchesIdentity(entry: *const StackEntry, identity: []const u8) bool {
    var short_identity_buffer: [constants.sizes.SHORT_DISPLAY_LENGTH]u8 = undefined;
    const short_identity_length = entry.getShortIdentity(&short_identity_buffer);
    return identitiesEqual(short_identity_buffer[0..short_identity_length], identity);
}
