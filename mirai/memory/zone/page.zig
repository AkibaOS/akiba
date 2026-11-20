//! Zone Page Payload And List Membership

const address = @import("utils").address;
const common = @import("common");
const fields = @import("mirai").memory.strings.zone.fields;
const tree = @import("common").datatypes.tree;
const types = @import("mirai").memory.types;

const sizes = common.constants.memory.sizes;
const FreeElement = types.zone.layout.FreeElement;
const Zone = types.zone.layout.Zone;
const ZonePageMeta = types.zone.layout.ZonePageMeta;

pub fn attach(zone: *Zone, meta: *ZonePageMeta, physical: u64, offset: usize) void {
    const virtual = address.translate.physToVirt(physical);
    meta.* = .{
        .Zone = zone,
        .PageVirtual = virtual,
        .PagePhysical = physical,
        .FreeList = null,
        .InUse = 0,
        .Next = null,
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
    prepend(&zone.PartialPages, meta);
    zone.PageCount += 1;
}

pub fn find(zone: *const Zone, page_virtual: usize) ?*ZonePageMeta {
    const node = tree.lookup.find(&zone.PageIndex, page_virtual) orelse return null;
    return @fieldParentPtr(fields.PAGE_INDEX, node);
}

pub fn prepend(head: *?*ZonePageMeta, meta: *ZonePageMeta) void {
    meta.Previous = null;
    meta.Next = head.*;
    if (head.*) |next| next.Previous = meta;
    head.* = meta;
}

pub fn unlink(head: *?*ZonePageMeta, meta: *ZonePageMeta) void {
    if (meta.Previous) |previous| {
        if (previous.Next != meta) unreachable;
        previous.Next = meta.Next;
    } else {
        if (head.* != meta) unreachable;
        head.* = meta.Next;
    }
    if (meta.Next) |next| {
        if (next.Previous != meta) unreachable;
        next.Previous = meta.Previous;
    }
    meta.Previous = null;
    meta.Next = null;
}
