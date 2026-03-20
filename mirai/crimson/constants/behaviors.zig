//! Exception Behaviors

pub const Behavior = enum(u8) {
    default = 0,
    state = 1,
    state_identity = 2,

    pub fn includes_state(self: Behavior) bool {
        return self == .state or self == .state_identity;
    }

    pub fn includes_identity(self: Behavior) bool {
        return self == .state_identity;
    }
};

pub const Action = enum(u8) {
    @"resume" = 0,
    skip = 1,
    terminate = 2,
    terminate_corpse = 3,
    collapse = 4,
    debug = 5,

    pub fn is_fatal(self: Action) bool {
        return self == .terminate or self == .terminate_corpse or self == .collapse;
    }

    pub fn name(self: Action) []const u8 {
        return switch (self) {
            .@"resume" => "Resume",
            .skip => "Skip",
            .terminate => "Terminate",
            .terminate_corpse => "Terminate with Corpse",
            .collapse => "Collapse",
            .debug => "Debug",
        };
    }
};
