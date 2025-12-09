//! Kata Control Block - Kernel's representation of a running persona program
//! Kata (形) = Form/pattern - a program's execution form

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
};

// Saved CPU context for context shifting
pub const Context = struct {
    // General purpose registers
    rax: u64 = 0,
    rbx: u64 = 0,
    rcx: u64 = 0,
    rdx: u64 = 0,
    rsi: u64 = 0,
    rdi: u64 = 0,
    rbp: u64 = 0,
    rsp: u64 = 0,
    r8: u64 = 0,
    r9: u64 = 0,
    r10: u64 = 0,
    r11: u64 = 0,
    r12: u64 = 0,
    r13: u64 = 0,
    r14: u64 = 0,
    r15: u64 = 0,

    // Instruction pointer and flags
    rip: u64 = 0,
    rflags: u64 = 0x202, // Interrupts enabled by default

    // Segment selectors
    cs: u64 = 0,
    ss: u64 = 0,
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
            .context = Context{},
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
                .context = Context{},
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
