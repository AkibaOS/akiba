//! Exception Type

const strings = @import("../strings/strings.zig");

const names = strings.names;

pub const ExceptionType = enum(u8) {
    Breach = 0,
    Forbidden = 1,
    Overflow = 2,
    Shatter = 3,
    Missing = 4,
    Critical = 5,
    Software = 6,
    Resource = 7,
    Guard = 8,
    Collapse = 9,

    pub fn isRecoverable(self: ExceptionType) bool {
        return switch (self) {
            .Breach, .Forbidden, .Overflow, .Shatter, .Missing, .Software, .Resource, .Guard => true,
            .Critical, .Collapse => false,
        };
    }

    pub fn name(self: ExceptionType) []const u8 {
        return switch (self) {
            .Breach => names.TYPE_BREACH,
            .Forbidden => names.TYPE_FORBIDDEN,
            .Overflow => names.TYPE_OVERFLOW,
            .Shatter => names.TYPE_SHATTER,
            .Missing => names.TYPE_MISSING,
            .Critical => names.TYPE_CRITICAL,
            .Software => names.TYPE_SOFTWARE,
            .Resource => names.TYPE_RESOURCE,
            .Guard => names.TYPE_GUARD,
            .Collapse => names.TYPE_COLLAPSE,
        };
    }

    pub fn description(self: ExceptionType) []const u8 {
        return switch (self) {
            .Breach => names.DESCRIPTION_BREACH,
            .Forbidden => names.DESCRIPTION_FORBIDDEN,
            .Overflow => names.DESCRIPTION_OVERFLOW,
            .Shatter => names.DESCRIPTION_SHATTER,
            .Missing => names.DESCRIPTION_MISSING,
            .Critical => names.DESCRIPTION_CRITICAL,
            .Software => names.DESCRIPTION_SOFTWARE,
            .Resource => names.DESCRIPTION_RESOURCE,
            .Guard => names.DESCRIPTION_GUARD,
            .Collapse => names.DESCRIPTION_COLLAPSE,
        };
    }
};
