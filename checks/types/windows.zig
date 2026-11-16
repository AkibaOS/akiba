//! Windows Process Containment Layouts

pub const ControlHandler = *const fn (u32) callconv(.winapi) i32;

pub const BasicLimits = extern struct {
    UserTime: i64 = 0,
    JobTime: i64 = 0,
    Flags: u32 = 0,
    MinimumWorkingSet: usize = 0,
    MaximumWorkingSet: usize = 0,
    ActiveProcessLimit: u32 = 0,
    Affinity: usize = 0,
    PriorityClass: u32 = 0,
    SchedulingClass: u32 = 0,
};

pub const Counters = extern struct {
    ReadOperations: u64 = 0,
    WriteOperations: u64 = 0,
    OtherOperations: u64 = 0,
    ReadBytes: u64 = 0,
    WriteBytes: u64 = 0,
    OtherBytes: u64 = 0,
};

pub const ExtendedLimits = extern struct {
    Basic: BasicLimits = .{},
    IO: Counters = .{},
    ProcessMemory: usize = 0,
    JobMemory: usize = 0,
    PeakProcessMemory: usize = 0,
    PeakJobMemory: usize = 0,
};

pub const Accounting = extern struct {
    UserTime: i64 = 0,
    KernelTime: i64 = 0,
    PeriodUserTime: i64 = 0,
    PeriodKernelTime: i64 = 0,
    PageFaults: u32 = 0,
    TotalProcesses: u32 = 0,
    ActiveProcesses: u32 = 0,
    TerminatedProcesses: u32 = 0,
};
