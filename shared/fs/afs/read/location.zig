//! AFS Location Operations

const constants = @import("../constants/constants.zig");
const types = @import("../types/types.zig");

const StackRecord = types.StackRecord;
const UnitRecord = types.UnitRecord;

pub const LocationError = error{
    NotFound,
    NotAStack,
    InvalidLocation,
    BTreeError,
};

/// Result of looking up a location
pub const LookupResult = union(enum) {
    unit: UnitRecord,
    stack: StackRecord,
    not_found: void,
};

/// Convert ASCII location component to UTF-16 identity
pub fn component_to_identity(component: []const u8, identity_buffer: []u16) usize {
    var len: usize = 0;
    for (component) |byte| {
        if (len >= identity_buffer.len) break;
        identity_buffer[len] = byte;
        len += 1;
    }
    return len;
}

/// Iterator for location components
pub const LocationIterator = struct {
    location: []const u8,
    position: usize,

    pub fn init(location: []const u8) LocationIterator {
        var start: usize = 0;
        // Skip leading separator
        if (location.len > 0 and (location[0] == '/' or location[0] == '\\')) {
            start = 1;
        }
        return LocationIterator{
            .location = location,
            .position = start,
        };
    }

    pub fn next(self: *LocationIterator) ?[]const u8 {
        // Skip empty components
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
