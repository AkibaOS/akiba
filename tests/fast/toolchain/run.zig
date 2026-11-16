//! Native Toolchain Image Integration Test Root

const image = @import("tests").fast.toolchain.image;

test "mkafsdisk creates reciprocal GPT FAT boot files and readable AFS units in one temporary image" {
    try image.integration.createAndReadback();
}
