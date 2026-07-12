//! GDT Assembly Operations

pub const lgdt_ops = @import("lgdt.zig");
pub const segments = @import("segments.zig");

pub const Gdtr = lgdt_ops.Gdtr;
pub const lgdt = lgdt_ops.lgdt;
pub const sgdt = lgdt_ops.sgdt;

pub const reload_code_segment = segments.reload_code_segment;
pub const reload_data_segments = segments.reload_data_segments;
pub const load_tss = segments.load_tss;

pub const get_cs = segments.get_cs;
pub const get_ds = segments.get_ds;
pub const get_ss = segments.get_ss;
pub const get_es = segments.get_es;
pub const get_fs = segments.get_fs;
pub const get_gs = segments.get_gs;
