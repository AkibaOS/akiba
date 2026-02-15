//! Hikari - The ELF loader
//! Hikari (光) = Light - illuminates programs into execution

const afs = @import("../fs/afs/afs.zig");
const ahci = @import("../drivers/ahci/ahci.zig");
const boot = @import("../boot/multiboot2.zig");
const elf = @import("elf.zig");
const format = @import("format.zig");
const gdt = @import("../boot/gdt.zig");
const heap = @import("../memory/heap.zig");
const kata_memory = @import("../kata/memory.zig");
const kata_mod = @import("../kata/kata.zig");
const sensei = @import("../kata/sensei.zig");
const serial = @import("../drivers/serial/serial.zig");
const system = @import("../system/system.zig");

pub fn init(fs: *afs.AFS(ahci.BlockDevice)) !u32 {
    const init_path = "/system/akiba/pulse.akibainit";

    // Validate init binary exists before attempting to load
    const init_size = fs.get_unit_size(init_path) catch |err| {
        serial.print("FATAL: Cannot find init system at ");
        serial.print(init_path);
        serial.print("\n");
        return err;
    };

    if (init_size == 0) {
        serial.print("FATAL: Init system is empty\n");
        return error.EmptyFile;
    }

    // Load init with just its path as argument
    var args: [1][]const u8 = .{init_path};
    return load_program_with_args(fs, init_path, &args);
}

pub fn load_program(fs: *afs.AFS(ahci.BlockDevice), path: []const u8) !u32 {
    var args: [1][]const u8 = .{path};
    return load_program_with_args(fs, path, &args);
}

pub fn load_program_with_args(
    fs: *afs.AFS(ahci.BlockDevice),
    path: []const u8,
    args: []const []const u8,
) !u32 {
    // Validate path
    if (path.len == 0 or path.len > system.limits.MAX_PATH_LENGTH) {
        return error.InvalidPath;
    }

    // Get actual file size from filesystem
    const file_size = try fs.get_unit_size(path);

    // Validate file size (programs should be reasonable size)
    if (file_size == 0) return error.EmptyFile;
    if (file_size > system.limits.MAX_FILE_SIZE) return error.FileTooLarge;

    const buffer_ptr = heap.alloc(@intCast(file_size)) orelse return error.OutOfMemory;
    defer heap.free(buffer_ptr, @intCast(file_size));
    const buffer = buffer_ptr[0..@intCast(file_size)];

    const bytes_read = try fs.view_unit_at(path, buffer);

    // Verify we read the expected amount
    if (bytes_read != file_size) {
        return error.IncompleteRead;
    }

    // Parse Akiba executable format
    const akiba_data = try format.parse_akiba(buffer[0..bytes_read]);

    // Parse ELF binary
    const elf_info = try elf.parse_elf(akiba_data.elf_data);

    // Create new kata
    const kata = try kata_mod.create_kata();
    errdefer kata_mod.dissolve_kata(kata.id);

    // Set parent to current kata (if any)
    if (sensei.get_current_kata()) |parent| {
        kata.parent_id = parent.id;

        // Inherit parent's current location
        for (0..parent.current_location_len) |i| {
            kata.current_location[i] = parent.current_location[i];
        }
        kata.current_location_len = parent.current_location_len;
        kata.current_cluster = parent.current_cluster;
    }

    // Setup kata memory (page table, stacks, framebuffer)
    const fb_info = boot.get_framebuffer();
    const fb_phys = if (fb_info) |fb| fb.addr else 0;
    const fb_size = if (fb_info) |fb| fb.height * fb.pitch else 0;
    try kata_memory.setup_kata_memory(kata, fb_phys, fb_size);

    // Load ELF segments into kata's address space
    for (elf_info.program_headers) |phdr| {
        if (phdr.type == elf.PT_LOAD) {
            try kata_memory.load_segment(
                kata,
                phdr.vaddr,
                akiba_data.elf_data,
                phdr.offset,
                phdr.filesz,
                phdr.memsz,
                phdr.flags,
            );
        }
    }

    // Setup arguments on user stack
    const adjusted_stack = try setup_user_stack_args(kata, args);

    // Setup execution context with adjusted stack pointer
    setup_kata_context(kata, elf_info.entry_point, adjusted_stack);

    // Add kata to scheduler
    sensei.enqueue_kata(kata);

    return kata.id;
}

/// Setup argument strings and pointers on the user stack
/// Returns the new stack pointer (pointing to pc)
fn setup_user_stack_args(kata: *kata_mod.Kata, args: []const []const u8) !u64 {
    const paging = @import("../memory/paging.zig");

    var stack_top = kata.user_stack_top;
    const pc: u64 = args.len;

    // Phase 1: Copy argument strings to stack (with null terminators)
    var string_addrs: [system.limits.MAX_ARGS]u64 = undefined;

    for (args, 0..) |arg, i| {
        const str_len = arg.len + 1;
        stack_top -= str_len;
        stack_top &= ~@as(u64, 0x7); // Align to 8 bytes

        string_addrs[i] = stack_top;

        const phys_addr = paging.virt_to_phys(kata.page_table, stack_top) orelse return error.StackNotMapped;
        const dest = @as([*]u8, @ptrFromInt(phys_addr + system.constants.HIGHER_HALF_START));

        for (arg, 0..) |c, j| {
            dest[j] = c;
        }
        dest[arg.len] = 0;
    }

    // Phase 2: Build pv array (pointers to strings)
    const pv_size = pc * 8;
    stack_top -= pv_size;
    stack_top &= ~@as(u64, 0x7);

    const pv_addr = stack_top;

    var i: usize = 0;
    while (i < pc) : (i += 1) {
        const ptr_phys = paging.virt_to_phys(kata.page_table, pv_addr + i * 8) orelse return error.StackNotMapped;
        const ptr_dest = @as(*u64, @ptrFromInt(ptr_phys + system.constants.HIGHER_HALF_START));
        ptr_dest.* = string_addrs[i];
    }

    // Align to 16 bytes BEFORE pushing pc and pv pointer
    stack_top &= ~@as(u64, 0xF);

    // Phase 3: Push pv pointer
    stack_top -= 8;
    const pv_ptr_phys = paging.virt_to_phys(kata.page_table, stack_top) orelse return error.StackNotMapped;
    @as(*u64, @ptrFromInt(pv_ptr_phys + system.constants.HIGHER_HALF_START)).* = pv_addr;

    // Phase 4: Push pc (parameter count)
    stack_top -= 8;
    const pc_phys = paging.virt_to_phys(kata.page_table, stack_top) orelse return error.StackNotMapped;
    @as(*u64, @ptrFromInt(pc_phys + system.constants.HIGHER_HALF_START)).* = pc;

    // Stack is now 16-byte aligned with RSP pointing at pc
    return stack_top;
}

fn setup_kata_context(kata: *kata_mod.Kata, entry_point: u64, stack_pointer: u64) void {
    kata.context.rip = entry_point;
    kata.context.rsp = stack_pointer;
    kata.context.rflags = 0x3202;
    kata.context.cs = gdt.USER_CODE | 3;
    kata.context.ss = gdt.USER_DATA | 3;

    // Zero all general-purpose registers
    kata.context.rax = 0;
    kata.context.rbx = 0;
    kata.context.rcx = 0;
    kata.context.rdx = 0;
    kata.context.rsi = 0;
    kata.context.rdi = 0;
    kata.context.rbp = 0;
    kata.context.r8 = 0;
    kata.context.r9 = 0;
    kata.context.r10 = 0;
    kata.context.r11 = 0;
    kata.context.r12 = 0;
    kata.context.r13 = 0;
    kata.context.r14 = 0;
    kata.context.r15 = 0;
}
