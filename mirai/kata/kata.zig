//! Kata Control Block - Kernel's representation of a running Akiba program
//! Kata (形) = Form/pattern - a program's execution form

const fd_mod = @import("fd.zig");
const paging = @import("../memory/paging.zig");
const serial = @import("../drivers/serial.zig");

pub const KataState = enum {
    Ready, // Ready to execute
    Running, // Currently executing
    Waiting, // Waiting for I/O or event
    Dissolved, // Terminated
};

pub const Kata = struct {
    // Kata identification
    id: u32, // Kata ID (like PID)

    // Execution state
    state: KataState,

    // Saved registers (for context shifting)
    context: Context,

    // Memory management
    page_table: u64, // CR3 value (physical address of PML4)
    stack_top: u64, // Top of kernel stack
    user_stack_top: u64, // Top of user stack

    // Location tracking (current stack/cluster in AFS)
    current_location: [256]u8,
    current_location_len: usize,
    current_cluster: u32,

    // Lineage
    parent_id: u32, // Parent Kata ID

    // CFS-lite scheduling
    vruntime: u64, // Virtual runtime (nanoseconds)
    weight: u32, // Priority weight (default 1024)
    last_run: u64, // Last time this Kata ran

    // Linked list for sorted vruntime queue (simple CFS-lite)
    next: ?*Kata,

    // File descriptors
    // fd 0 = /system/devices/source (input)
    // fd 1 = /system/devices/stream (output)
    // fd 2 = /system/devices/trace (errors)
    fd_table: [16]fd_mod.FileDescriptor = [_]fd_mod.FileDescriptor{.{}} ** 16,
    next_fd: u32 = 3,
};

// Saved CPU context for context shifting
// Must be extern struct to guarantee memory layout matches assembly offsets:
// rax=0, rbx=8, rcx=16, rdx=24, rsi=32, rdi=40, rbp=48, rsp=56
// r8=64, r9=72, r10=80, r11=88, r12=96, r13=104, r14=112, r15=120
// rip=128, rflags=136, cs=144, ss=152
pub const Context = extern struct {
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
const MAX_KATA: usize = 256;
var kata_pool: [MAX_KATA]Kata = undefined;
var kata_used: [MAX_KATA]bool = [_]bool{false} ** MAX_KATA;
var next_kata_id: u32 = 1;

pub fn init() void {
    serial.print("\n=== Kata Management ===\n");

    // Initialize all Kata slots
    for (&kata_pool, 0..) |*kata, i| {
        kata.* = Kata{
            .id = 0,
            .state = .Dissolved,
            .context = Context.init(),
            .page_table = 0,
            .stack_top = 0,
            .user_stack_top = 0,
            .current_location = undefined,
            .current_location_len = 1,
            .current_cluster = 0,
            .parent_id = 0,
            .vruntime = 0,
            .weight = 1024,
            .last_run = 0,
            .next = null,
        };
        kata_used[i] = false;
    }

    serial.print("Kata pool initialized (");
    serial.print_hex(MAX_KATA);
    serial.print(" slots)\n");
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
                .current_location = undefined,
                .current_location_len = 1,
                .current_cluster = 0,
                .parent_id = 0,
                .vruntime = 0,
                .weight = 1024,
                .last_run = 0,
                .next = null,
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

pub fn get_kata(kata_id: u32) ?*Kata {
    for (&kata_pool, 0..) |*kata, i| {
        if (kata_used[i] and kata.id == kata_id) {
            return kata;
        }
    }
    return null;
}

pub fn dissolve_kata(kata_id: u32) void {
    for (&kata_pool, 0..) |*kata, i| {
        if (kata_used[i] and kata.id == kata_id) {
            kata.state = .Dissolved;
            kata_used[i] = false;
            return;
        }
    }
}
