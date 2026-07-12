//! Crimson Messages

pub const SEPARATOR = "================================================================================\n";
pub const COLLAPSE_HEADER = "                              AKIBA HAS COLLAPSED                              \n";
pub const REASON = "Reason: %s\n";
pub const SYSTEM_HALTED = "System halted. Please restart your computer.\n";

pub const CPU_CONTEXT_HEADER = "CPU Context:\n";
pub const REG_RAX_RBX = "  RAX: %x  RBX: %x\n";
pub const REG_RCX_RDX = "  RCX: %x  RDX: %x\n";
pub const REG_RSI_RDI = "  RSI: %x  RDI: %x\n";
pub const REG_RBP_RSP = "  RBP: %x  RSP: %x\n";
pub const REG_R8_R9 = "  R8:  %x  R9:  %x\n";
pub const REG_R10_R11 = "  R10: %x  R11: %x\n";
pub const REG_R12_R13 = "  R12: %x  R13: %x\n";
pub const REG_R14_R15 = "  R14: %x  R15: %x\n";
pub const REG_RIP_RFLAGS = "  RIP: %x  RFLAGS: %x\n";
pub const CONTROL_REGISTERS_HEADER = "Control Registers:\n";
pub const REG_CR0_CR2 = "  CR0: %x  CR2: %x\n";
pub const REG_CR3_CR4 = "  CR3: %x  CR4: %x\n";
pub const SEGMENT_REGISTERS_HEADER = "Segment Registers:\n";
pub const REG_CS_DS_ES = "  CS: %x  DS: %x  ES: %x\n";
pub const REG_FS_GS_SS = "  FS: %x  GS: %x  SS: %x\n";

pub const EXCEPTION_LINE = "Exception: %s (%s)\n";
pub const VECTOR = "  Vector: %d\n";
pub const CODE = "  Code: %x\n";
pub const SUBCODE = "  Subcode: %x\n";
pub const FAULT_ADDRESS = "  Fault Address: %x\n";
pub const LOCATION = "  Location: %s mode\n";
pub const LOCATION_KERNEL = "kernel";
pub const LOCATION_USER = "user";
pub const KATA_THREAD = "  Kata: %d, Thread: %d\n";
pub const ACCESS = "  Access: %s\n";
pub const MODE_USER = "  Mode: User\n";
pub const MODE_KERNEL = "  Mode: Kernel\n";
pub const FAULTING_INSTRUCTION_HEADER = "Faulting Instruction:\n";
pub const ADDRESS = "  Address: %x\n";
pub const BYTES_LABEL = "  Bytes: ";

pub const MEMORY_AROUND = "Memory around %x:\n";
pub const INSTRUCTION_BYTES = "Instruction bytes at %x:\n  ";

pub const STACK_TRACE_HEADER = "Stack Trace:\n";
pub const NO_STACK_FRAMES = "  (no stack frames available)\n";
pub const RAW_STACK = "Raw Stack (from %x):\n";

pub const MODULES_NONE = "Loaded Modules: (none registered)\n\n";
pub const MODULES_HEADER = "Loaded Modules:\n";
pub const MODULE_ENTRY = "  %s: %x - %x (%d bytes)\n";

pub const DUMP_REGISTERS_GENERAL_1 = "RAX: %x  RBX: %x  RCX: %x  RDX: %x\n";
pub const DUMP_REGISTERS_GENERAL_2 = "RSI: %x  RDI: %x  RBP: %x  RSP: %x\n";
pub const DUMP_REGISTERS_GENERAL_3 = "R8:  %x  R9:  %x  R10: %x  R11: %x\n";
pub const DUMP_REGISTERS_GENERAL_4 = "R12: %x  R13: %x  R14: %x  R15: %x\n";
pub const DUMP_REGISTERS_INSTRUCTION = "RIP: %x  RFLAGS: %x\n";
pub const DUMP_REGISTERS_CONTROL = "CR0: %x  CR2: %x  CR3: %x  CR4: %x\n";

pub const CORPSE_INVALID = "Invalid corpse\n";
pub const CORPSE_HEADER = "Corpse for Kata %d, Thread %d\n";
pub const CORPSE_EXCEPTION = "Exception: %s (code=%x, subcode=%x)\n";
pub const CORPSE_FAULT_ADDRESS = "Fault address: %x\n";

pub const TERMINATE_KATA_THREAD = "Terminating kata %d, thread %d due to unhandled exception\n";
pub const TERMINATE_KATA_CORPSE = "Terminating kata %d with corpse generation\n";

pub const DOUBLE_COLLAPSE = "\nDouble collapse detected, halting immediately\n";

pub const KERNEL_PAGE_FAULT = "Kernel page fault at %x: %s\n";
pub const FATAL_UNRECOVERABLE = "FATAL: Unrecoverable exception (vector %d) at %x\n";
pub const KERNEL_FORBIDDEN = "Kernel forbidden exception at %x (vector %d, error %x)\n";
pub const KERNEL_ARITHMETIC = "Kernel arithmetic exception at %x\n";

pub const KERNEL_PANIC = "\nKERNEL PANIC: %s\n";
