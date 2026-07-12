//! AFS Location Operations

const types = @import("../types/types.zig");

const StackRecord = types.catalog.StackRecord;
const UnitRecord = types.catalog.UnitRecord;

pub const LookupResult = union(enum) {
    Unit: UnitRecord,
    Stack: StackRecord,
    NotFound: void,
};

pub fn componentToIdentity(component: []const u8, identity_buffer: []u16) usize {
    var length: usize = 0;
    for (component) |byte| {
        if (length >= identity_buffer.len) break;
        identity_buffer[length] = byte;
        length += 1;
    }
    return length;
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
