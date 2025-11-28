# akiba

Drifting from abyss towards the infinite!

```
┌─────────────────────────────────────────────────┐
│           Akiba Memory Architecture             │
├─────────────────────────────────────────────────┤
│ Physical Memory Manager (PMM)                   │
│  - Bitmap-based page tracking                   │
│  - 4KB page allocation/freeing                  │
│  - 2037 MB available memory                     │
├─────────────────────────────────────────────────┤
│ Page Table Manager                              │
│  - Dynamic page mapping                         │
│  - 4-level paging (PML4/PDPT/PD/PT)             │
│  - Can map new regions on demand                │
├─────────────────────────────────────────────────┤
│ Heap Allocator                                  │
│  - Size-segregated caches (16B-2048B)           │
│  - O(1) allocation and free                     │
│  - Automatic slab management                    │
│  - Large allocation support (>2KB)              │
├─────────────────────────────────────────────────┤
│ Memory Layout:                                  │
│  0x0000000000100000+ : Kernel code (identity)   │
│  0xFFFF800000500000+ : PMM bitmap               │
│  0xFFFF800000510000+ : Heap slabs               │
└─────────────────────────────────────────────────┘
```
