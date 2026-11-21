//! Choose A Compatible Driver Without Directory Order Precedence

const std = @import("std");

const Candidate = @import("pulse").devices.types.catalog.Candidate;
const Key = @import("shared").device.types.instance.Key;

pub fn choose(candidates: []const Candidate, device: Key, override: ?[]const u8) ![]const u8 {
    var selected: ?[]const u8 = null;
    for (candidates) |candidate| {
        const match = candidate.Description.Match;
        if (match.Kind != device.Kind or (match.Location != null and match.Location.? != device.Location)) continue;
        if (override) |name| if (!std.mem.eql(u8, name, candidate.Identity)) continue;
        if (selected != null) return error.AmbiguousDriver;
        selected = candidate.Identity;
    }
    return selected orelse if (override != null) error.InvalidSelection else error.NoDriver;
}
