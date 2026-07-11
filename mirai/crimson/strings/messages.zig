//! Crimson Messages

pub const separator = "================================================================================\n";
pub const collapse_header = "                              AKIBA HAS COLLAPSED                              \n";
pub const reason = "Reason: %s\n";
pub const system_halted = "System halted. Please restart your computer.\n";

pub const cpu_context_header = "CPU Context:\n";
pub const reg_rax_rbx = "  RAX: %x  RBX: %x\n";
pub const reg_rcx_rdx = "  RCX: %x  RDX: %x\n";
pub const reg_rsi_rdi = "  RSI: %x  RDI: %x\n";
pub const reg_rbp_rsp = "  RBP: %x  RSP: %x\n";
pub const reg_r8_r9 = "  R8:  %x  R9:  %x\n";
pub const reg_r10_r11 = "  R10: %x  R11: %x\n";
pub const reg_r12_r13 = "  R12: %x  R13: %x\n";
pub const reg_r14_r15 = "  R14: %x  R15: %x\n";
pub const reg_rip_rflags = "  RIP: %x  RFLAGS: %x\n";
pub const control_registers_header = "Control Registers:\n";
pub const reg_cr0_cr2 = "  CR0: %x  CR2: %x\n";
pub const reg_cr3_cr4 = "  CR3: %x  CR4: %x\n";
pub const segment_registers_header = "Segment Registers:\n";
pub const reg_cs_ds_es = "  CS: %x  DS: %x  ES: %x\n";
pub const reg_fs_gs_ss = "  FS: %x  GS: %x  SS: %x\n";

pub const exception_line = "Exception: %s (%s)\n";
pub const vector = "  Vector: %d\n";
pub const code = "  Code: %x\n";
pub const subcode = "  Subcode: %x\n";
pub const fault_address = "  Fault Address: %x\n";
pub const location = "  Location: %s mode\n";
pub const location_kernel = "kernel";
pub const location_user = "user";
pub const kata_thread = "  Kata: %d, Thread: %d\n";
pub const access = "  Access: %s\n";
pub const mode_user = "  Mode: User\n";
pub const mode_kernel = "  Mode: Kernel\n";
pub const faulting_instruction_header = "Faulting Instruction:\n";
pub const address = "  Address: %x\n";
pub const bytes_label = "  Bytes: ";

pub const memory_around = "Memory around %x:\n";
pub const instruction_bytes = "Instruction bytes at %x:\n  ";

pub const stack_trace_header = "Stack Trace:\n";
pub const no_stack_frames = "  (no stack frames available)\n";
pub const raw_stack = "Raw Stack (from %x):\n";

pub const modules_none = "Loaded Modules: (none registered)\n\n";
pub const modules_header = "Loaded Modules:\n";
pub const module_entry = "  %s: %x - %x (%d bytes)\n";

pub const dump_registers_general_1 = "RAX: %x  RBX: %x  RCX: %x  RDX: %x\n";
pub const dump_registers_general_2 = "RSI: %x  RDI: %x  RBP: %x  RSP: %x\n";
pub const dump_registers_general_3 = "R8:  %x  R9:  %x  R10: %x  R11: %x\n";
pub const dump_registers_general_4 = "R12: %x  R13: %x  R14: %x  R15: %x\n";
pub const dump_registers_instruction = "RIP: %x  RFLAGS: %x\n";
pub const dump_registers_control = "CR0: %x  CR2: %x  CR3: %x  CR4: %x\n";

pub const corpse_invalid = "Invalid corpse\n";
pub const corpse_header = "Corpse for Kata %d, Thread %d\n";
pub const corpse_exception = "Exception: %s (code=%x, subcode=%x)\n";
pub const corpse_fault_address = "Fault address: %x\n";

pub const terminate_kata_thread = "Terminating kata %d, thread %d due to unhandled exception\n";
pub const terminate_kata_corpse = "Terminating kata %d with corpse generation\n";

pub const double_collapse = "\nDouble collapse detected, halting immediately\n";

pub const kernel_page_fault = "Kernel page fault at %x: %s\n";
pub const fatal_unrecoverable = "FATAL: Unrecoverable exception (vector %d) at %x\n";
pub const kernel_forbidden = "Kernel forbidden exception at %x (vector %d, error %x)\n";
pub const kernel_arithmetic = "Kernel arithmetic exception at %x\n";

pub const kernel_panic = "\nKERNEL PANIC: %s\n";
