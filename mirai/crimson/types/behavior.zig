//! Exception Behavior and Action

const strings = @import("mirai").crimson.strings;

const names = strings.names;

pub const Behavior = enum(u8) {
    Default = 0,
    State = 1,
    StateIdentity = 2,

    pub fn includesState(self: Behavior) bool {
        return self == .State or self == .StateIdentity;
    }

    pub fn includesIdentity(self: Behavior) bool {
        return self == .StateIdentity;
    }
};

pub const Action = enum(u8) {
    Resume = 0,
    Skip = 1,
    Terminate = 2,
    TerminateCorpse = 3,
    Collapse = 4,
    Debug = 5,

    pub fn isFatal(self: Action) bool {
        return self == .Terminate or self == .TerminateCorpse or self == .Collapse;
    }

    pub fn name(self: Action) []const u8 {
        return switch (self) {
            .Resume => names.ACTION_RESUME,
            .Skip => names.ACTION_SKIP,
            .Terminate => names.ACTION_TERMINATE,
            .TerminateCorpse => names.ACTION_TERMINATE_CORPSE,
            .Collapse => names.ACTION_COLLAPSE,
            .Debug => names.ACTION_DEBUG,
        };
    }
};
