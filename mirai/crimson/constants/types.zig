//! Exception Types

pub const ExceptionType = enum(u8) {
    breach = 0,
    forbidden = 1,
    overflow = 2,
    shatter = 3,
    missing = 4,
    critical = 5,
    software = 6,
    resource = 7,
    guard = 8,
    collapse = 9,

    pub fn is_recoverable(self: ExceptionType) bool {
        return switch (self) {
            .breach, .forbidden, .overflow, .shatter, .missing, .software, .resource, .guard => true,
            .critical, .collapse => false,
        };
    }

    pub fn name(self: ExceptionType) []const u8 {
        return switch (self) {
            .breach => "Breach",
            .forbidden => "Forbidden",
            .overflow => "Overflow",
            .shatter => "Shatter",
            .missing => "Missing",
            .critical => "Critical",
            .software => "Software",
            .resource => "Resource",
            .guard => "Guard",
            .collapse => "Collapse",
        };
    }

    pub fn description(self: ExceptionType) []const u8 {
        return switch (self) {
            .breach => "Memory access failure",
            .forbidden => "Illegal operation",
            .overflow => "Arithmetic exception",
            .shatter => "Debug or breakpoint",
            .missing => "Resource not available",
            .critical => "System-level interrupt",
            .software => "Software-raised exception",
            .resource => "Resource limit exceeded",
            .guard => "Guarded resource violation",
            .collapse => "Unrecoverable error",
        };
    }
};
