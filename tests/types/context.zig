//! Native Thread Context Check Types

const kagami = @import("mirai").kagami.types.kagami;
const thread = @import("mirai").thread.types.thread;

pub const Registers = extern struct {
    RBX: u64 = 0,
    RBP: u64 = 0,
    R12: u64 = 0,
    R13: u64 = 0,
    R14: u64 = 0,
    R15: u64 = 0,
};

pub const Floating = extern struct {
    X87: [2]u64 = .{ 0, 0 },
    XMM0: [2]u64 = .{ 0, 0 },
    XMM15: [2]u64 = .{ 0, 0 },
    MXCSR: u32 = 0,
    Control: u16 = 0,
};

pub const Cooperative = extern struct {
    Seed: Registers = .{},
    Actual: Registers = .{},
    BeforeRSP: u64 = 0,
    AfterRSP: u64 = 0,
    BeforeFlags: u64 = 0,
    AfterFlags: u64 = 0,
};

pub const Preemptive = extern struct {
    SeedRegisters: Registers = .{},
    ActualRegisters: Registers = .{},
    Seed: Floating = .{},
    Actual: Floating = .{},
    Stage: u32 = 0,
    TimedOut: u32 = 0,
    Budget: u64 = 0,
    BeforeFlags: u64 = 0,
    AfterFlags: u64 = 0,
};

pub const Yield = *const fn (?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) void;
pub const CooperativeBoundary = *const fn (*Cooperative, Yield, ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) void;
pub const PreemptiveBoundary = *const fn (*Preemptive, *const Preemptive) callconv(.{ .x86_64_sysv = .{} }) void;

pub const Worker = struct {
    OwnerID: u64 = 0,
    Target: ?*thread.Thread = null,
    ExpectedCR3: u64 = 0,
    StackBase: u64 = 0,
    StackTop: u64 = 0,
    Cooperative: Cooperative = .{},
    Preemptive: Preemptive = .{},
    Peer: ?*const Preemptive = null,
    EntryCount: u32 = 0,
    YieldReturns: u32 = 0,
    ArgumentMatched: bool = false,
    RegistersValid: bool = true,
    StackValid: bool = true,
    InterruptsValid: bool = true,
    CR3Valid: bool = true,
    TSSValid: bool = true,
    Done: bool = false,
};

pub const Baseline = struct {
    Current: *thread.Thread,
    AddressSpace: *kagami.Kagami,
    CR3: u64,
    RSP0: u64,
    Flags: u64,
    RegisteredCount: u16,
    OwnerThreadCount: u64,
    Requests: u64,
    Switches: u64,
};
