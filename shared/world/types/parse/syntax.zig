//! Inert World Node And Value Records

pub const Value = struct {
    Text: []const u8,
    Quoted: bool,
    Annotation: ?[]const u8 = null,
};

pub const Property = struct {
    Name: []const u8,
    Value: Value,
};

pub const Node = struct {
    Name: []const u8,
    Annotation: ?[]const u8,
    Parent: ?usize,
    Arguments: []const Value,
    Properties: []const Property,
    Disabled: bool,
};
