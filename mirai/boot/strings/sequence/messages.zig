//! Boot Sequence Diagnostics

pub const NEWLINE = "\n";
pub const LINE = "%s\n";

pub const STARTING = "Starting Akiba boot sequence\n";
pub const POWERED = "Powered by the Mirai kernel\n\n";

pub const TSS_SETUP = "Setting up Task State Segment for CPU exceptions\n";
pub const GDT_SETUP = "Setting up Global Descriptor Table with kernel and user segments\n";

pub const NO_BITMAP = "  No suitable location for page bitmap\n";
pub const FOUND_PAGES = "  Found %d pages (%d MB total)\n";
pub const AVAILABLE = "  Available: %d pages (%d MB)\n";
pub const PML4 = "  Using PML4 at physical address %x\n";
pub const NO_STACK = "  Boot kernel stack allocation failed\n";
pub const STACK_INFO = "  Stack base %x, top %x\n";

pub const IDT_SETUP = "Loading Interrupt Descriptor Table and remapping PIC\n";
pub const TIMER_SETUP = "Configuring PIT timer and registering IRQ0\n";
pub const KEYBOARD_SETUP = "Registering keyboard handler on IRQ1\n";
pub const INTERRUPTS_ENABLED = "  Interrupts enabled (timer + keyboard)\n";
