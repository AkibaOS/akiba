//! Location Component Iterator

const constants = @import("../constants/constants.zig");

const separators = constants.separators;

pub const LocationIterator = struct {
    Location: []const u8,
    Position: usize,

    pub fn init(location: []const u8) LocationIterator {
        var start: usize = 0;
        if (location.len > 0 and isSeparator(location[0])) {
            start = 1;
        }
        return LocationIterator{
            .Location = location,
            .Position = start,
        };
    }

    pub fn next(self: *LocationIterator) ?[]const u8 {
        while (self.Position < self.Location.len and isSeparator(self.Location[self.Position])) {
            self.Position += 1;
        }

        if (self.Position >= self.Location.len) {
            return null;
        }

        const start = self.Position;
        while (self.Position < self.Location.len and !isSeparator(self.Location[self.Position])) {
            self.Position += 1;
        }

        if (self.Position == start) {
            return null;
        }

        return self.Location[start..self.Position];
    }
};

fn isSeparator(character: u8) bool {
    return character == separators.FORWARD_SLASH or character == separators.BACK_SLASH;
}
