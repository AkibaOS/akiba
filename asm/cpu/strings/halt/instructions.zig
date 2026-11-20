//! Interrupt Safe Idle Instructions

pub const HALT = "hlt";
pub const PAUSE = "pause";
pub const WAIT_FOR_INTERRUPT = "sti; hlt";
