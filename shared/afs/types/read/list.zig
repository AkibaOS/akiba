//! Read Only AFS Stack Child Records

const IndexKey = @import("shared").afs.types.btree.records.IndexKey;

pub const Kind = enum(u16) { Stack, Unit };

pub const Entry = extern struct {
    Kind: Kind,
    Length: u16,
    Identity: [@as(IndexKey, undefined).Identity.len]u16 = @splat(0),
};
