//! Boot Sequence Messages

pub const NEWLINE = "\n";

pub const STARTING = "Starting Akiba boot sequence\n";
pub const POWERED = "Powered by the Mirai kernel\n\n";
pub const CPU_FAILED = "\nCPU initialization failed, cannot continue\n";
pub const MEMORY_FAILED = "\nMemory initialization failed, cannot continue\n";
pub const COMPLETE = "\nBoot sequence complete, Akiba is ready\n";
pub const HALTED = "\nSystem halted due to unrecoverable error\n";

pub const TSS_SETUP = "Setting up Task State Segment for CPU exceptions\n";
pub const GDT_SETUP = "Setting up Global Descriptor Table with kernel and user segments\n";

pub const DETECTING = "Detecting physical memory from Hikari bootloader\n";
pub const NO_BITMAP = "  Could not find suitable location for page bitmap\n";
pub const FOUND_PAGES = "  Found %d pages (%d MB total)\n";
pub const AVAILABLE = "  Available: %d pages (%d MB)\n";
pub const KAGAMI_SETUP = "Setting up Kagami page table abstraction\n";
pub const PML4 = "  Using PML4 at physical address %x\n";
pub const PROVISIONING_STACK = "Provisioning boot kernel stack with guard pages\n";
pub const NO_STACK = "  Could not allocate boot kernel stack\n";
pub const STACK_INFO = "  Stack base %x, top %x\n";

pub const INTERRUPTS_FAILED = "\nInterrupt initialization failed, cannot continue\n";
pub const IDT_SETUP = "Loading Interrupt Descriptor Table and remapping PIC\n";
pub const TIMER_SETUP = "Configuring PIT timer and registering IRQ0\n";
pub const KEYBOARD_SETUP = "Registering keyboard handler on IRQ1\n";
pub const INTERRUPTS_ENABLED = "  Interrupts enabled (timer + keyboard)\n";
