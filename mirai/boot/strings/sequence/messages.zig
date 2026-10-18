//! Boot Sequence Diagnostics

pub const NEWLINE = "\n";
pub const LINE = "%s\n";

pub const STARTING = "Starting Akiba boot sequence\n";
pub const POWERED = "Powered by the Mirai kernel\n\n";

pub const NO_EXECUTE_UNAVAILABLE = "  Processor rejected no-execute page protection\n";
pub const TSS_SETUP = "Verifying early Task State Segment and exception stacks\n";
pub const GDT_SETUP = "Verifying early Global Descriptor Table\n";
pub const EARLY_STATE_UNAVAILABLE = "  Early processor or exception state unavailable\n";
pub const EARLY_STATE_READY = "  Early processor and exception state ready\n";

pub const INVALID_BOOT_INFO = "Invalid Kernel Startup Information";
pub const ROOT_PREPARE_FAILED = "  Kernel map preparation failed: %s\n";
pub const OWNED_ROOT = "  Owned PML4 %x; loader PML4 %x; %d table pages\n";
pub const HIGH_STACK_ACTIVE = "  Active high RSP %x\n";
pub const LOW_IDENTITY_REMOVED = "  Low identity mappings absent\n";

pub const INVALID_PHYSMAP = "  Unsupported physical-memory mapping\n";
pub const PHYSMAP_COVERAGE = "  Physmap coverage: %d MB\n";
pub const BITMAP_STORAGE = "  Page bitmap: %d bytes at %x\n";
pub const NO_BITMAP = "  No suitable location for page bitmap\n";
pub const FOUND_PAGES = "  Found %d pages (%d MB total)\n";
pub const AVAILABLE = "  Available: %d pages (%d MB)\n";
pub const NO_ZONES = "  Zone allocator initialization failed\n";
pub const NO_KALLOC = "  Kernel allocator initialization failed\n";
pub const ALLOCATOR_READY = "  Kernel allocator ready with %d size classes\n";
pub const PML4 = "  Using PML4 at physical address %x\n";
pub const NO_STACK = "  Boot kernel stack allocation failed\n";
pub const STACK_INFO = "  Stack base %x, top %x\n";

pub const IDT_SETUP = "Installing hardware interrupt gates and remapping PIC\n";
pub const TIMER_SETUP = "Configuring PIT timer and registering IRQ0\n";
pub const KEYBOARD_SETUP = "Registering keyboard handler on IRQ1\n";
pub const INTERRUPTS_ENABLED = "  Interrupts enabled (timer + keyboard)\n";
