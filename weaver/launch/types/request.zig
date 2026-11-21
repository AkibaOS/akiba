//! Private Weaver Transport And Launch Options

const image = @import("weaver").image.types.layout;
const provision = @import("shared").launch.types.provision;

const Cache = @import("weaver").launch.types.cache.state.Cache;
const Policy = @import("shared").elf.types.image.Policy;

pub const Options = struct {
    Biases: ?image.Biases = null,
    Policy: Policy,
    StackBase: u64,
    StackPages: u64,
    StartupBase: u64,
    Identity: []const u8,
    Parameters: []const u8,
    Cache: ?*Cache = null,
};

pub const Spans = struct {
    GuardedStack: image.Interval,
    Startup: image.Interval,
    StackLength: u64,
};

pub const Channel = struct {
    Ticket: u64,
    Context: *anyopaque,
    Invoke: *const fn (*anyopaque, u64, provision.Operation, u64, provision.Protection) provision.Result,
};
