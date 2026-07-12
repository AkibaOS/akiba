//! Hikari Boot Sequence Messages

pub const TITLE = "Hikari Bootloader\r\n";
pub const TITLE_UNDERLINE = "=================\r\n\r\n";

pub const INITIALIZING_GRAPHICS = "Initializing graphics...\r\n";
pub const ERROR_GRAPHICS_OUTPUT = "ERROR: Failed to get graphics output\r\n";

pub const LOCATING_AFS_PARTITION = "Locating AFS partition...\r\n";
pub const ERROR_AFS_PARTITION_NOT_FOUND = "ERROR: AFS partition not found\r\n";

pub const INITIALIZING_AFS = "Initializing AFS...\r\n";
pub const ERROR_AFS_INITIALIZE = "ERROR: Failed to initialize AFS\r\n";

pub const LOADING_KERNEL = "Loading kernel: ";
pub const NEWLINE = "\r\n";
pub const ERROR_KERNEL_NOT_FOUND = "ERROR: Kernel not found\r\n";
pub const ERROR_KERNEL_READ = "ERROR: Failed to read kernel\r\n";

pub const VALIDATING_ELF = "Validating ELF...\r\n";
pub const ERROR_INVALID_ELF = "ERROR: Invalid ELF format\r\n";

pub const LOADING_KERNEL_MEMORY = "Loading kernel into memory...\r\n";
pub const ERROR_KERNEL_LOAD = "ERROR: Failed to load kernel\r\n";

pub const SETTING_UP_PAGE_TABLES = "Setting up page tables...\r\n";
pub const ERROR_PAGE_TABLES = "ERROR: Failed to setup page tables\r\n";

pub const ALLOCATING_KERNEL_STACK = "Allocating kernel stack...\r\n";
pub const ERROR_STACK_ALLOCATION = "ERROR: Failed to allocate stack\r\n";

pub const PREPARING_BOOT_PARAMETERS = "Preparing boot parameters...\r\n";
pub const ERROR_BOOT_PARAMS_ALLOCATION = "ERROR: Failed to allocate boot params\r\n";

pub const GETTING_MEMORY_MAP = "Getting memory map...\r\n";
pub const ERROR_MEMORY_MAP = "ERROR: Failed to get memory map\r\n";

pub const EXITING_BOOT_SERVICES = "Exiting boot services...\r\n";
