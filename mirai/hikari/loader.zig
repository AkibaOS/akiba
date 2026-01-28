//! Hikari - The ELF loader
//! Hikari (光) = Light - illuminates programs into execution

const afs = @import("../fs/afs.zig");
const ahci = @import("../drivers/ahci.zig");
const boot = @import("../boot/multiboot2.zig");
const elf = @import("elf.zig");
const format = @import("format.zig");
const gdt = @import("../boot/gdt.zig");
const heap = @import("../memory/heap.zig");
const kata_memory = @import("../kata/memory.zig");
const kata_mod = @import("../kata/kata.zig");
const sensei = @import("../kata/sensei.zig");
const serial = @import("../drivers/serial.zig");
const system = @import("../system/system.zig");

pub fn init(fs: *afs.AFS(ahci.BlockDevice)) !u32 {
    const init_path = "/system/akiba/pulse.akibainit";

    // Validate init binary exists before attempting to load
    const init_size = fs.get_file_size_by_path(init_path) catch |err| {
        serial.print("FATAL: Cannot find init system at ");
        serial.print(init_path);
        serial.print("\n");
        return err;
    };

    if (init_size == 0) {
        serial.print("FATAL: Init system is empty\n");
        return error.EmptyFile;
    }

    return load_program(fs, init_path);
}

pub fn load_program(fs: *afs.AFS(ahci.BlockDevice), path: []const u8) !u32 {
    // Validate path
    if (path.len == 0 or path.len > system.limits.MAX_PATH_LENGTH) {
        return error.InvalidPath;
    }

    // Get actual file size from filesystem
    const file_size = try fs.get_file_size_by_path(path);

    // Validate file size (programs should be reasonable size)
    if (file_size == 0) return error.EmptyFile;
    if (file_size > system.limits.MAX_FILE_SIZE) return error.FileTooLarge;
    const buffer_ptr = heap.alloc(@intCast(file_size)) orelse return error.OutOfMemory;
    defer heap.free(buffer_ptr, @intCast(file_size));
    const buffer = buffer_ptr[0..@intCast(file_size)];

    const bytes_read = try fs.read_file_by_path(path, buffer);

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

    // Setup execution context
    setup_kata_context(kata, elf_info.entry_point);

    // Add kata to scheduler
    sensei.enqueue_kata(kata);

    return kata.id;
}

fn setup_kata_context(kata: *kata_mod.Kata, entry_point: u64) void {
    kata.context.rip = entry_point;
    kata.context.rsp = kata.user_stack_top;
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
