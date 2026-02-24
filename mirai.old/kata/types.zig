//! Kata type definitions

const attachment = @import("attachment.zig");
const kata_const = @import("../common/constants/kata.zig");
const kata_limits = @import("../common/limits/kata.zig");

pub const State = enum {
    Born, // Just created, being initialized
    Alive, // Ready to run, waiting for scheduler
    Flowing, // Currently executing
    Stalled, // Waiting for child/event
    Frozen, // Blocked on I/O
    Dying, // Exit called, cleanup starting
    Zombie, // Exited, awaiting Shinigami
    Dissolved, // Gone, slot reusable
};

pub const Mode = enum {
    Persona, // Normal user process - can be reaped
    Protected, // System process - page tables are protected
};

pub const Context = packed struct {
    rax: u64,
    rbx: u64,
    rcx: u64,
    rdx: u64,
    rsi: u64,
    rdi: u64,
    rbp: u64,
    rsp: u64,
    r8: u64,
    r9: u64,
    r10: u64,
    r11: u64,
    r12: u64,
    r13: u64,
    r14: u64,
    r15: u64,
    rip: u64,
    rflags: u64,
    cs: u64,
    ss: u64,

    pub fn init() Context {
        return Context{
            .rax = 0,
            .rbx = 0,
            .rcx = 0,
            .rdx = 0,
            .rsi = 0,
            .rdi = 0,
            .rbp = 0,
            .rsp = 0,
            .r8 = 0,
            .r9 = 0,
            .r10 = 0,
            .r11 = 0,
            .r12 = 0,
            .r13 = 0,
            .r14 = 0,
            .r15 = 0,
            .rip = 0,
            .rflags = kata_const.KERNEL_RFLAGS,
            .cs = 0,
            .ss = 0,
        };
    }
};

pub const Kata = struct {
    id: u32,
    state: State,
    mode: Mode,
    context: Context,

    page_table: u64,
    stack_top: u64,
    user_stack_top: u64,
    user_stack_bottom: u64,
    user_stack_committed: u64,

    attachments: [kata_limits.MAX_ATTACHMENTS]?*attachment.Attachment,

    current_location: [kata_limits.MAX_LOCATION_LENGTH]u8,
    current_location_len: usize,
    current_cluster: u64,

    parent_id: u32,

    letter_type: u8,
    letter_data: ?[*]u8,
    letter_len: u16,
    letter_capacity: u16,

    vruntime: u64,
    weight: u32,
    last_run: u64,
    next: ?*Kata,

    waiting_for: u32,
    exit_code: u64,
};

pub const InterruptContext = packed struct {
    r15: u64,
    r14: u64,
    r13: u64,
    r12: u64,
    r11: u64,
    r10: u64,
    r9: u64,
    r8: u64,
    rbp: u64,
    rdi: u64,
    rsi: u64,
    rdx: u64,
    rcx: u64,
    rbx: u64,
    rax: u64,
    int_num: u64,
    error_code: u64,
    rip: u64,
    cs: u64,
    rflags: u64,
    rsp: u64,
    ss: u64,
};
