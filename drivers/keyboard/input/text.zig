//! Map Unprefixed Set 1 Keys To Default US Text

const std = @import("std");

const layout = @import("keyboard").strings.input.layout;
const scan = @import("keyboard").constants.input.scancode;

pub fn character(code: u8, shift: bool, caps: bool) ?u8 {
    const base = row(code, scan.NUMBER_ROW, layout.NUMBER, layout.NUMBER_SHIFTED, shift) orelse
        row(code, scan.TOP_ROW, layout.TOP, layout.TOP_SHIFTED, shift) orelse
        row(code, scan.MIDDLE_ROW, layout.MIDDLE, layout.MIDDLE_SHIFTED, shift) orelse
        row(code, scan.BOTTOM_ROW, layout.BOTTOM, layout.BOTTOM_SHIFTED, shift) orelse
        switch (code) {
            scan.BACKSLASH => if (shift) @as(u8, '|') else '\\',
            scan.SPACE => ' ',
            else => return null,
        };
    if (caps and std.ascii.isAlphabetic(base)) return if (shift) std.ascii.toLower(base) else std.ascii.toUpper(base);
    return base;
}

fn row(code: u8, first: u8, normal: []const u8, shifted: []const u8, shift: bool) ?u8 {
    if (code < first or code - first >= normal.len) return null;
    return (if (shift) shifted else normal)[code - first];
}
