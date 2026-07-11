//! Hikari Boot Sequence Messages

pub const title = "Hikari Bootloader\r\n";
pub const title_underline = "=================\r\n\r\n";

pub const initializing_graphics = "Initializing graphics...\r\n";
pub const error_graphics_output = "ERROR: Failed to get graphics output\r\n";

pub const locating_afs_partition = "Locating AFS partition...\r\n";
pub const error_afs_partition_not_found = "ERROR: AFS partition not found\r\n";

pub const initializing_afs = "Initializing AFS...\r\n";
pub const error_afs_initialize = "ERROR: Failed to initialize AFS\r\n";

pub const loading_kernel = "Loading kernel: ";
pub const newline = "\r\n";
pub const error_kernel_not_found = "ERROR: Kernel not found\r\n";
pub const error_kernel_read = "ERROR: Failed to read kernel\r\n";

pub const validating_elf = "Validating ELF...\r\n";
pub const error_invalid_elf = "ERROR: Invalid ELF format\r\n";

pub const loading_kernel_memory = "Loading kernel into memory...\r\n";
pub const error_kernel_load = "ERROR: Failed to load kernel\r\n";

pub const setting_up_page_tables = "Setting up page tables...\r\n";
pub const error_page_tables = "ERROR: Failed to setup page tables\r\n";

pub const allocating_kernel_stack = "Allocating kernel stack...\r\n";
pub const error_stack_allocation = "ERROR: Failed to allocate stack\r\n";

pub const preparing_boot_parameters = "Preparing boot parameters...\r\n";
pub const error_boot_params_allocation = "ERROR: Failed to allocate boot params\r\n";

pub const getting_memory_map = "Getting memory map...\r\n";
pub const error_memory_map = "ERROR: Failed to get memory map\r\n";

pub const exiting_boot_services = "Exiting boot services...\r\n";
