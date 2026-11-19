//! Compiler Shared Library With Per Kata Writable State

const INITIAL_COUNTER: u64 = 3;
const INITIAL_OFFSET: u64 = 7;

export var linked_counter: u64 = INITIAL_COUNTER;
var offset: u64 = INITIAL_OFFSET;
export var linked_offset: *u64 = &offset;

export fn linked_step() callconv(.c) u64 {
    linked_counter +%= 1;
    return linked_counter +% linked_offset.*;
}
