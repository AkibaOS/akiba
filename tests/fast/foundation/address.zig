//! Address Arithmetic Regression Checks

const std = @import("std");

const constants = @import("tests").fast.constants.foundation.vectors;
const decompose = @import("common").paging.decompose;
const translate = @import("common").memory.translate;

pub fn pagingIndices() !void {
    for (constants.PAGING_INDICES_CASES) |case| {
        try std.testing.expectEqual(case.PML4, decompose.extractPML4Index(case.Address));
        try std.testing.expectEqual(case.PDPT, decompose.extractPDPTIndex(case.Address));
        try std.testing.expectEqual(case.PD, decompose.extractPDIndex(case.Address));
        try std.testing.expectEqual(case.PT, decompose.extractPTIndex(case.Address));
    }
}

pub fn pageConversionBoundaries() !void {
    try std.testing.expectEqual(@as(u64, 0), translate.addressToPage(0));
    try std.testing.expectEqual(@as(u64, 0), translate.addressToPage(0xfff));
    try std.testing.expectEqual(@as(u64, 1), translate.addressToPage(0x1000));
    try std.testing.expectEqual(@as(u64, 0x123456789), translate.addressToPage(0x123456789abc));
    try std.testing.expectEqual(@as(u64, 0xfffffffffffff), translate.addressToPage(0xffffffffffffffff));
    try std.testing.expectEqual(@as(u64, 0), translate.pageToAddress(0));
    try std.testing.expectEqual(@as(u64, 0x1000), translate.pageToAddress(1));
    try std.testing.expectEqual(@as(u64, 0x123456789000), translate.pageToAddress(0x123456789));
    try std.testing.expectEqual(@as(u64, 0xfffffffffffff000), translate.pageToAddress(0xfffffffffffff));
}

pub fn pageRoundTrips() !void {
    const addresses = [_]u64{ 0, 0x1000, 0x123456789000, 0xffff800000001000, 0xfffffffffffff000 };
    const pages = [_]u64{ 0, 1, 0x123456789, 0xffff800000001, 0xfffffffffffff };

    for (addresses, pages) |address, page| {
        try std.testing.expectEqual(page, translate.addressToPage(address));
        try std.testing.expectEqual(address, translate.pageToAddress(page));
        try std.testing.expectEqual(address, translate.pageToAddress(translate.addressToPage(address)));
        try std.testing.expectEqual(page, translate.addressToPage(translate.pageToAddress(page)));
    }
}

pub fn physicalMapRoundTrips() !void {
    const physical_addresses = [_]u64{ 0, 0x123, 0x100000, 0x123456789, 0x7fffffffff };
    const virtual_addresses = [_]u64{ 0xffff800000000000, 0xffff800000000123, 0xffff800000100000, 0xffff800123456789, 0xffff807fffffffff };

    for (physical_addresses, virtual_addresses) |physical_address, virtual_address| {
        try std.testing.expectEqual(virtual_address, translate.physToVirt(physical_address));
        try std.testing.expectEqual(physical_address, translate.virtToPhys(virtual_address));
        try std.testing.expectEqual(physical_address, translate.virtToPhys(translate.physToVirt(physical_address)));
        try std.testing.expectEqual(virtual_address, translate.physToVirt(translate.virtToPhys(virtual_address)));
    }
}
