//! AFS Catalog Node Validation

const constants = @import("shared").afs.constants;
const node = @import("shared").afs.btree.node;
const types = @import("shared").afs.types;

pub fn catalogNode(buffer: []const u8) bool {
    if (buffer.len < @sizeOf(types.btree.NodeDescriptor) or buffer.len > constants.sizes.MAXIMUM_CELL_SIZE) return false;
    const descriptor = @as(*align(1) const types.btree.NodeDescriptor, @ptrCast(buffer.ptr)).*;
    if (!descriptor.isLeaf() and !descriptor.isIndex()) return false;
    const offset_bytes = @as(usize, descriptor.RecordCount) * @sizeOf(u16);
    if (offset_bytes > buffer.len - @sizeOf(types.btree.NodeDescriptor)) return false;
    const record_limit = buffer.len - offset_bytes;
    var record_index: u16 = 0;
    while (record_index < descriptor.RecordCount) : (record_index += 1) {
        const start: usize = node.getRecordOffset(buffer.ptr, @intCast(buffer.len), record_index);
        const end: usize = if (record_index + 1 < descriptor.RecordCount)
            node.getRecordOffset(buffer.ptr, @intCast(buffer.len), record_index + 1)
        else
            record_limit;
        if (start < @sizeOf(types.btree.NodeDescriptor) or start >= end or end > record_limit or
            end - start < constants.btree.INDEX_KEY_HEADER_SIZE)
        {
            return false;
        }
        const key: *align(1) const types.btree.IndexKey = @ptrCast(buffer.ptr + start);
        if (key.KeyLength < constants.btree.INDEX_KEY_HEADER_SIZE or key.KeyLength > end - start or
            (key.KeyLength - constants.btree.INDEX_KEY_HEADER_SIZE) % @sizeOf(u16) != 0 or
            key.getIdentityLength() > key.Identity.len)
        {
            return false;
        }
        const payload = buffer[start + key.KeyLength .. end];
        if (descriptor.isIndex()) {
            if (payload.len < @sizeOf(u32)) return false;
            continue;
        }
        if (payload.len < @sizeOf(u16)) return false;
        const record_type: *align(1) const u16 = @ptrCast(payload.ptr);
        switch (record_type.*) {
            constants.records.INDEX_STACK => if (payload.len < @sizeOf(types.catalog.StackRecord)) return false,
            constants.records.INDEX_UNIT => if (payload.len < @sizeOf(types.catalog.UnitRecord)) return false,
            constants.records.INDEX_STACK_THREAD, constants.records.INDEX_UNIT_THREAD => {
                const header_size = @offsetOf(types.catalog.ThreadRecord, "Identity");
                if (payload.len < header_size) return false;
                const thread: *align(1) const types.catalog.ThreadRecord = @ptrCast(payload.ptr);
                if (thread.IdentityLength > thread.Identity.len or
                    @as(usize, thread.IdentityLength) * @sizeOf(u16) > payload.len - header_size)
                {
                    return false;
                }
            },
            else => return false,
        }
    }
    return true;
}
