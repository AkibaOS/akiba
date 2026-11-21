//! Private Initial Device Driver Admission Operations

pub const Operation = enum(u64) { StartAhci, ConfirmAhci, StartAfs, ConfirmAfs, BindDevice };
