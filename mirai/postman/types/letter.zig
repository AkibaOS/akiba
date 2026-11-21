//! Copied Letter Views

const Header = @import("shared").persona.types.letter.Header;

pub const View = struct {
    Header: Header,
    Payload: []const u8,
};
