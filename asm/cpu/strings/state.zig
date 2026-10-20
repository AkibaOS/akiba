//! CPU State Instructions

pub const READ_STACK_POINTER = "mov %%rsp, %[value]";
pub const READ_BASE_POINTER = "mov %%rbp, %[value]";
pub const READ_FLAGS = "pushfq; pop %[value]";
pub const READ_TIME_STAMP_COUNTER = "rdtsc";
pub const CLEAR_TASK_SWITCHED =
    \\mov %%cr0, %%rax
    \\and $~8, %%rax
    \\mov %%rax, %%cr0
;
