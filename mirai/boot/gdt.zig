//! Global Descriptor Table - Extended for Layer 0-3

const cpu = @import("../asm/cpu.zig");
const io = @import("../asm/io.zig");
const serial = @import("../drivers/serial.zig");
const tss = @import("tss.zig");

// GDT Entry structure
const GDTEntry = packed struct {
    limit_low: u16,
    base_low: u16,
    base_middle: u8,
    access: u8,
    granularity: u8,
    base_high: u8,
};

// TSS descriptor (128 bits in x64)
const TSSDescriptor = packed struct {
    length: u16,
    base_low: u16,
    base_middle: u8,
    flags1: u8,
    flags2: u8,
    base_high: u8,
    base_upper: u32,
    reserved: u32,
};

// GDT Pointer for LGDT
const GDTPointer = packed struct {
    limit: u16,
    base: u64,
};

// GDT with 6 entries + TSS (128-bit)
var gdt: [8]u64 align(16) = undefined;
var gdt_ptr: GDTPointer = undefined;

// Segment selectors
pub const KERNEL_CODE: u16 = 0x08;
pub const KERNEL_DATA: u16 = 0x10;
pub const USER_DATA: u16 = 0x18; // Must come before user code for sysret
pub const USER_CODE: u16 = 0x20;
pub const TSS_SEGMENT: u16 = 0x28;

pub fn init() void {
    serial.print("\n=== Global Descriptor Table ===\n");

    // Entry 0: Null descriptor
    gdt[0] = 0;

    // Entry 1: Kernel Code (0x08) - Layer 0
    // Base: 0, Limit: 0xFFFFF, 64-bit, executable, readable, DPL=0
    gdt[1] = create_code_descriptor(0, true, false);

    // Entry 2: Kernel Data (0x10) - Layer 0
    // Base: 0, Limit: 0xFFFFF, writable, DPL=0
    gdt[2] = create_data_descriptor(0, false);

    // Entry 3: User Data (0x18) - Layer 3
    // Base: 0, Limit: 0xFFFFF, writable, DPL=3
    gdt[3] = create_data_descriptor(3, true);

    // Entry 4: User Code (0x20) - Layer 3
    // Base: 0, Limit: 0xFFFFF, 64-bit, executable, readable, DPL=3
    gdt[4] = create_code_descriptor(3, true, true);

    // Entry 5-6: TSS (0x28) - 128-bit descriptor
    const tss_addr = tss.get_address();
    const tss_size = tss.get_size();
    create_tss_descriptor(tss_addr, tss_size);

    // Set up GDT pointer
    gdt_ptr = GDTPointer{
        .limit = @sizeOf(@TypeOf(gdt)) - 1,
        .base = @intFromPtr(&gdt),
    };

    // Load new GDT
    load_gdt();

    // Load TSS
    load_tss();

    serial.print("GDT loaded with Layer 0-3 segments\n");
    serial.print("Kernel Code: 0x");
    serial.print_hex(KERNEL_CODE);
    serial.print("\n");
    serial.print("Kernel Data: 0x");
    serial.print_hex(KERNEL_DATA);
    serial.print("\n");
    serial.print("User Code: 0x");
    serial.print_hex(USER_CODE);
    serial.print("\n");
    serial.print("User Data: 0x");
    serial.print_hex(USER_DATA);
    serial.print("\n");
    serial.print("TSS: 0x");
    serial.print_hex(TSS_SEGMENT);
    serial.print("\n");

    // Mask all IRQs on both PICs
    serial.print("Masking all hardware interrupts...\n");
    io.write_port_byte(0x21, 0xFF); // Master PIC
    io.write_port_byte(0xA1, 0xFF); // Slave PIC
}

fn create_code_descriptor(dpl: u8, long_mode: bool, is_user: bool) u64 {
    _ = is_user;
    var descriptor: u64 = 0;

    // Limit (bits 0-15, 48-51): 0xFFFFF
    descriptor |= 0xFFFF;
    descriptor |= (@as(u64, 0xF) << 48);

    // Access byte (bits 40-47)
    var access: u8 = 0;
    access |= (1 << 0); // Accessed
    access |= (1 << 1); // Readable
    access |= (1 << 3); // Code segment
    access |= (1 << 4); // Code/Data descriptor
    access |= (@as(u8, dpl & 0x3) << 5); // DPL
    access |= (1 << 7); // Present
    descriptor |= (@as(u64, access) << 40);

    // Flags (bits 52-55)
    var flags: u8 = 0;
    flags |= (1 << 3); // Granularity (4KB)
    if (long_mode) {
        flags |= (1 << 1); // Long mode
    } else {
        flags |= (1 << 2); // 32-bit
    }
    descriptor |= (@as(u64, flags) << 52);

    return descriptor;
}

fn create_data_descriptor(dpl: u8, is_user: bool) u64 {
    _ = is_user;
    var descriptor: u64 = 0;

    // Limit (bits 0-15, 48-51): 0xFFFFF
    descriptor |= 0xFFFF;
    descriptor |= (@as(u64, 0xF) << 48);

    // Access byte (bits 40-47)
    var access: u8 = 0;
    access |= (1 << 0); // Accessed
    access |= (1 << 1); // Writable
    access |= (1 << 4); // Code/Data descriptor
    access |= (@as(u8, dpl & 0x3) << 5); // DPL
    access |= (1 << 7); // Present
    descriptor |= (@as(u64, access) << 40);

    // Flags (bits 52-55)
    var flags: u8 = 0;
    flags |= (1 << 3); // Granularity (4KB)
    flags |= (1 << 2); // 32-bit (data segments don't use long mode bit)
    descriptor |= (@as(u64, flags) << 52);

    return descriptor;
}

fn create_tss_descriptor(base: u64, limit: u64) void {
    var desc_low: u64 = 0;
    var desc_high: u64 = 0;

    // Low 64 bits
    desc_low |= (limit & 0xFFFF); // Limit low
    desc_low |= ((base & 0xFFFF) << 16); // Base low
    desc_low |= ((base & 0xFF0000) >> 16) << 32; // Base middle
    desc_low |= (@as(u64, 0x89) << 40); // Type: Available TSS, Present
    desc_low |= (((limit >> 16) & 0xF) << 48); // Limit high
    desc_low |= (((base & 0xFF000000) >> 24) << 56); // Base high

    // High 64 bits - just upper 32 bits of base
    desc_high = (base >> 32) & 0xFFFFFFFF;

    gdt[5] = desc_low;
    gdt[6] = desc_high;
}

fn load_gdt() void {
    cpu.load_global_descriptor_table(@intFromPtr(&gdt_ptr));
    cpu.reload_segment_registers(KERNEL_DATA);
    cpu.reload_code_segment(KERNEL_CODE);
}

fn load_tss() void {
    cpu.load_task_register(TSS_SEGMENT);
}
