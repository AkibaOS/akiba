//! Kata Control Block - Kernel's representation of a running Akiba program
//! Kata (形) = Form/pattern - a program's execution form

const fd_mod = @import("fd.zig");
const paging = @import("../memory/paging.zig");
const serial = @import("../drivers/serial.zig");
const system = @import("../system/system.zig");

pub const KataState = enum {
    Ready,
    Running,
    Waiting,
    Blocked,
    Dissolved,
};

pub const Kata = struct {
    id: u32,
    state: KataState,

    // Execution context
    context: Context,

    // Memory
    page_table: u64,
    stack_top: u64,
    user_stack_top: u64,

    // File descriptors
    fd_table: [system.limits.MAX_FILE_DESCRIPTORS]fd_mod.FileDescriptor,

    // Working directory
    current_location: [system.limits.MAX_CWD_LENGTH]u8,
    current_location_len: usize,
    current_cluster: u64,

    // Process hierarchy
    parent_id: u32,

    // Postman - for Signals to parent
    letter_type: u8,
    letter_data: [system.limits.MAX_LETTER_LENGTH]u8,
    letter_len: u8,

    // Scheduling
    vruntime: u64,
    weight: u32,
    last_run: u64,
    next: ?*Kata,

    // Process control
    waiting_for: u32,
    exit_code: u64,
};

// Saved CPU context for context shifting
pub const Context = packed struct {
    // General purpose registers
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

    // Instruction pointer and flags
    rip: u64,
    rflags: u64,

    // Segment selectors
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
            .rflags = 0x202, // Interrupts enabled
            .cs = 0,
            .ss = 0,
        };
    }
};

// Kata table (pool of all Kata slots)
pub var kata_pool: [system.limits.MAX_PROCESSES]Kata = undefined;
pub var kata_used: [system.limits.MAX_PROCESSES]bool = [_]bool{false} ** system.limits.MAX_PROCESSES;
var next_kata_id: u32 = 1;

pub fn init() void {
    // Initialize all Kata slots
    for (&kata_pool, 0..) |*kata, i| {
        kata.* = Kata{
            .id = 0,
            .state = .Dissolved,
            .context = Context.init(),
            .page_table = 0,
            .stack_top = 0,
            .user_stack_top = 0,
            .fd_table = [_]fd_mod.FileDescriptor{.{}} ** system.limits.MAX_FILE_DESCRIPTORS,
            .current_location = undefined,
            .current_location_len = 1,
            .current_cluster = 0,
            .parent_id = 0,
            .letter_type = 0,
            .letter_data = undefined,
            .letter_len = 0,
            .vruntime = 0,
            .weight = 1024,
            .last_run = 0,
            .next = null,
            .waiting_for = 0,
            .exit_code = 0,
        };
        kata_used[i] = false;
    }
}

pub fn create_kata() !*Kata {
    // Find free slot in pool
    for (&kata_pool, 0..) |*kata, i| {
        if (!kata_used[i]) {
            kata_used[i] = true;

            const kata_id = next_kata_id;
            next_kata_id += 1;

            kata.* = Kata{
                .id = kata_id,
                .state = .Ready,
                .context = Context.init(),
                .page_table = 0,
                .stack_top = 0,
                .user_stack_top = 0,
                .fd_table = [_]fd_mod.FileDescriptor{.{}} ** system.limits.MAX_FILE_DESCRIPTORS,
                .current_location = undefined,
                .current_location_len = 1,
                .current_cluster = 0,
                .parent_id = 0,
                .letter_type = 0,
                .letter_data = undefined,
                .letter_len = 0,
                .vruntime = 0,
                .weight = 1024,
                .last_run = 0,
                .next = null,
                .waiting_for = 0,
                .exit_code = 0,
            };

            // Initialize location to root
            kata.current_location[0] = '/';

            // Initialize standard file descriptors
            kata.fd_table[0] = fd_mod.FileDescriptor{
                .fd_type = .Device,
                .device_type = .Source,
                .flags = fd_mod.VIEW_ONLY,
            };

            kata.fd_table[1] = fd_mod.FileDescriptor{
                .fd_type = .Device,
                .device_type = .Stream,
                .flags = fd_mod.MARK_ONLY,
            };

            kata.fd_table[2] = fd_mod.FileDescriptor{
                .fd_type = .Device,
                .device_type = .Trace,
                .flags = fd_mod.MARK_ONLY,
            };

            return kata;
        }
    }

    return error.TooManyKata;
}

pub fn get_kata(id: u32) ?*Kata {
    var i: usize = 0;
    while (i < system.limits.MAX_PROCESSES) : (i += 1) {
        if (kata_used[i] and kata_pool[i].id == id) {
            return &kata_pool[i];
        }
    }
    return null;
}

pub fn dissolve_kata(kata_id: u32) void {
    const sensei = @import("sensei.zig");

    for (&kata_pool, 0..) |*kata, i| {
        if (kata_used[i] and kata.id == kata_id) {
            kata.state = .Dissolved;
            kata_used[i] = false;

            // Wake any katas waiting for this one
            sensei.wake_waiting_katas(kata_id);

            return;
        }
    }
}
