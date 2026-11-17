//! Zone Page Payload Construction

const address = @import("utils").address;
const common = @import("common");
const tree = @import("common").datatypes.tree;
const types = @import("mirai").memory.types;

const sizes = common.constants.memory.sizes;
const FreeElement = types.zone.FreeElement;
const Zone = types.zone.Zone;
const ZonePageMeta = types.zone.ZonePageMeta;

pub fn attach(zone: *Zone, meta: *ZonePageMeta, physical: u64, offset: usize) void {
    const virtual = address.translate.physToVirt(physical);
    meta.* = .{
        .Zone = zone,
        .PageVirtual = virtual,
        .PagePhysical = physical,
        .FreeList = null,
        .InUse = 0,
        .Next = zone.PartialPages,
        .ElementOffset = offset,
        .Capacity = (sizes.PAGE_SIZE - offset) / zone.ElementSize,
    };
    const base: [*]u8 = @ptrFromInt(virtual);
    var index: usize = 0;
    while (index < meta.Capacity) : (index += 1) {
        const element: *FreeElement = @ptrCast(@alignCast(base + offset + index * zone.ElementSize));
        element.Next = meta.FreeList;
        meta.FreeList = element;
    }
    if (!tree.insert.insert(&zone.PageIndex, &meta.Index, virtual)) unreachable;
    zone.PartialPages = meta;
    zone.PageCount += 1;
}
