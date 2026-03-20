//! State Flavors

pub const Flavor = enum(u8) {
    none = 0, general = 1, float = 2, debug = 3, avx = 4, full = 5,
    pub fn includes_general(self: Flavor) bool { return self == .general or self == .full; }
    pub fn includes_float(self: Flavor) bool { return self == .float or self == .full; }
    pub fn includes_debug(self: Flavor) bool { return self == .debug or self == .full; }
    pub fn name(self: Flavor) []const u8 {
        return switch (self) { .none => "None", .general => "General", .float => "Float", .debug => "Debug", .avx => "AVX", .full => "Full" };
    }
};
