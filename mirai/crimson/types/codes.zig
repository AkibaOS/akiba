//! Exception Codes

pub const BreachCode = enum(u8) { PageNotPresent = 0, PageProtection = 1, PageWrite = 2, PageExecute = 3, PageUser = 4, SegmentNotPresent = 5, StackFault = 6, StackOverflow = 7 };
pub const ForbiddenCode = enum(u8) { InvalidOpcode = 0, GeneralProtection = 1, PrivilegeViolation = 2, AlignmentCheck = 3, BoundRange = 4 };
pub const OverflowCode = enum(u8) { DivideByZero = 0, IntegerOverflow = 1, FpuError = 2, SimdError = 3 };
pub const ShatterCode = enum(u8) { Breakpoint = 0, SingleStep = 1, Watchpoint = 2, DebugException = 3 };
pub const MissingCode = enum(u8) { FpuNotAvailable = 0, DeviceNotAvailable = 1 };
pub const CriticalCode = enum(u8) { NMI = 0, MachineCheck = 1 };
pub const SoftwareCode = enum(u8) { Assertion = 0, Abort = 1, UserDefined = 2 };
pub const ResourceCode = enum(u8) { MemoryLimit = 0, CpuLimit = 1, FileLimit = 2 };
pub const GuardCode = enum(u8) { PortGuard = 0, FileGuard = 1, MemoryGuard = 2 };
pub const CollapseCode = enum(u8) { DoubleFault = 0, TripleFault = 1, MachineCheck = 2, KernelPanic = 3, InvalidTSS = 4 };
