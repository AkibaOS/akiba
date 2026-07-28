//! Hikari Boot Sequence Messages

pub const INITIALIZING_DISPLAY = "Initializing Display";
pub const LOCATING_FILE_SYSTEM = "Locating Akiba File System";
pub const INITIALIZING_FILE_SYSTEM = "Initializing Akiba File System";
pub const LOADING_KERNEL = "Loading Mirai Kernel";
pub const VERIFYING_KERNEL = "Verifying Kernel Image";
pub const PREPARING_KERNEL = "Placing Kernel In Memory";
pub const PREPARING_MEMORY = "Preparing System Memory";
pub const RESERVING_KERNEL_MEMORY = "Reserving Kernel Memory";
pub const PREPARING_STARTUP = "Preparing Startup Information";
pub const SURVEYING_MEMORY = "Surveying System Memory";
pub const STARTING_AKIBA = "Starting Akiba";

pub const ERROR_DISPLAY = "Display Not Available";
pub const ERROR_FILE_SYSTEM_NOT_FOUND = "Akiba File System Not Found";
pub const ERROR_FILE_SYSTEM = "Akiba File System Failed";
pub const ERROR_KERNEL_NOT_FOUND = "Mirai Kernel Not Found";
pub const ERROR_KERNEL_READ = "Mirai Kernel Unreadable";
pub const ERROR_KERNEL_DAMAGED = "Invalid Mirai Kernel";
pub const ERROR_KERNEL_LOAD = "Mirai Kernel Load Failed";
pub const ERROR_MEMORY = "System Memory Setup Failed";
pub const ERROR_KERNEL_MEMORY = "Not Enough Memory for Mirai Kernel";
pub const ERROR_STARTUP = "Not Enough Memory to Start Akiba";
pub const ERROR_MEMORY_SURVEY = "System Memory Survey Failed";
