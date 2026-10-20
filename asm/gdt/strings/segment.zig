//! Segment Register Instructions

pub const READ_CODE_SEGMENT = "mov %%cs, %[value]";
pub const READ_DATA_SEGMENT = "mov %%ds, %[value]";
pub const READ_STACK_SEGMENT = "mov %%ss, %[value]";
pub const READ_EXTRA_SEGMENT = "mov %%es, %[value]";
pub const READ_FS_SEGMENT = "mov %%fs, %[value]";
pub const READ_GS_SEGMENT = "mov %%gs, %[value]";

pub const RELOAD_CODE_SEGMENT =
    \\push %[selector]
    \\lea 1f(%%rip), %%rax
    \\push %%rax
    \\lretq
    \\1:
;

pub const RELOAD_DATA_SEGMENTS =
    \\mov %[selector], %%ax
    \\mov %%ax, %%ds
    \\mov %%ax, %%es
    \\mov %%ax, %%fs
    \\mov %%ax, %%gs
    \\mov %%ax, %%ss
;

pub const LOAD_TASK_STATE_SEGMENT = "ltr %[selector]";
