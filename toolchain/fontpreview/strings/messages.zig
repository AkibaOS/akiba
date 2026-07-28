//! fontpreview Messages

pub const USAGE = "usage: {s} <font.ttf>\n";
pub const FACE = "face upem={d} glyphs={d} ascender={d} descender={d} linegap={d}\n";
pub const GLYPH = "glyph codepoint={d} id={d} advance={d} contours={d} points={d}\n";
pub const CONTOUR = "contour {d} start={d} end={d}\n";
pub const POINT = "point {d} {d} {d}\n";
