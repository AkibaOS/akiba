//! Kernel Boot Status Messages

pub const PROCESSOR = "Initializing Processor";
pub const SYSTEM_MEMORY = "Detecting System Memory";
pub const KAGAMI = "Initializing Kagami";
pub const KERNEL_MEMORY = "Provisioning Kernel Memory";
pub const SYSTEM_SERVICES = "Starting System Services";
pub const READY = "Akiba Is Ready";

pub const ERROR_PROCESSOR = "Processor Initialization Failed";
pub const ERROR_MEMORY = "System Memory Initialization Failed";
pub const ERROR_SERVICES = "System Services Failed to Start";
pub const ERROR_HALTED = "Akiba Could Not Start";
