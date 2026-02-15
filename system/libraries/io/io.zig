//! I/O operations

pub const attachment = @import("attachment.zig");
pub const stream_ops = @import("stream.zig");
pub const location = @import("location.zig");
pub const letter = @import("letter.zig");
pub const types = @import("types.zig");

pub const attach = attachment.attach;
pub const seal = attachment.seal;
pub const viewstack = attachment.viewstack;

pub const view = stream_ops.view;
pub const mark = stream_ops.mark;
pub const getchar = stream_ops.getchar;
pub const wipe = stream_ops.wipe;

pub const getlocation = location.get;
pub const setlocation = location.set;

pub const sendLetter = letter.send;
pub const readLetter = letter.read;

pub const StackEntry = types.StackEntry;
pub const FileDescriptor = types.FileDescriptor;
pub const Letter = types.Letter;
pub const Error = types.Error;

pub const source = types.source;
pub const stream = types.stream;
pub const trace = types.trace;

pub const VIEW_ONLY = types.VIEW_ONLY;
pub const MARK_ONLY = types.MARK_ONLY;
pub const BOTH = types.BOTH;
pub const CREATE = types.CREATE;
