//! FPU Instructions

pub const SAVE_FPU_STATE = "fxsave (%[address])";
pub const RESTORE_FPU_STATE = "fxrstor (%[address])";
pub const INITIALIZE_FPU = "fninit";
pub const CLEAR_FPU_EXCEPTIONS = "fnclex";
pub const STORE_MXCSR = "stmxcsr (%[address])";
pub const LOAD_MXCSR = "ldmxcsr (%[address])";
