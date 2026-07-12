//! Boot Sequence Messages

pub const newline = "\n";

pub const starting = "Starting Akiba boot sequence\n";
pub const powered = "Powered by the Mirai kernel\n\n";
pub const cpu_failed = "\nCPU initialization failed, cannot continue\n";
pub const memory_failed = "\nMemory initialization failed, cannot continue\n";
pub const complete = "\nBoot sequence complete, Akiba is ready\n";
pub const halted = "\nSystem halted due to unrecoverable error\n";

pub const tss_setup = "Setting up Task State Segment for CPU exceptions\n";
pub const gdt_setup = "Setting up Global Descriptor Table with kernel and user segments\n";

pub const detecting = "Detecting physical memory from Hikari bootloader\n";
pub const no_bitmap = "  Could not find suitable location for page bitmap\n";
pub const found_pages = "  Found %d pages (%d MB total)\n";
pub const available = "  Available: %d pages (%d MB)\n";
pub const kagami_setup = "Setting up Kagami page table abstraction\n";
pub const pml4 = "  Using PML4 at physical address %x\n";
pub const provisioning_stack = "Provisioning boot kernel stack with guard pages\n";
pub const no_stack = "  Could not allocate boot kernel stack\n";
pub const stack_info = "  Stack base %x, top %x\n";

pub const interrupts_failed = "\nInterrupt initialization failed, cannot continue\n";
pub const idt_setup = "Loading Interrupt Descriptor Table and remapping PIC\n";
pub const timer_setup = "Configuring PIT timer and registering IRQ0\n";
pub const keyboard_setup = "Registering keyboard handler on IRQ1\n";
pub const interrupts_enabled = "  Interrupts enabled (timer + keyboard)\n";
