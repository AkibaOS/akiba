/*
 * Global Descriptor Table (GDT) Implementation
 *
 * The GDT is a data structure used by x86 and x86_64 architectures to define memory segments.
 * This implementation sets up a minimal GDT for a 64-bit kernel with:
 *   - A null descriptor (required by the CPU)
 *   - A kernel code segment descriptor
 *   - A kernel data segment descriptor
 *
 * In long mode (64-bit), segmentation is largely vestigial, but the GDT is still required
 * for privilege levels and task switching. The base and limit values are mostly ignored
 * except for a few special cases.
 */

#include <arch/gdt.hpp>

namespace AkibaOS
{
    namespace GDT
    {
        /* Array to hold the three GDT entries (null, code, data) */
        Entry entries[3];

        /* GDT pointer structure that will be loaded into the GDTR register */
        Pointer pointer;

        /* External ASM function that loads the GDT using the LGDT instruction */
        extern "C" void load_gdt(Pointer *gdt_pointer);

        /*
         * Configures a single GDT entry with the specified parameters
         *
         * @param index       Index in the GDT table (0-2)
         * @param base        32-bit base address for the segment
         * @param limit       20-bit limit value for the segment
         * @param access      Access permissions and type flags
         * @param granularity Granularity settings and size flags
         */
        void set_entry(uint32_t index, uint32_t base, uint32_t limit, uint8_t access, uint8_t granularity)
        {
            /* Split the base address into its component parts */
            entries[index].base_low = base & 0xFFFF;
            entries[index].base_middle = (base >> 16) & 0xFF;
            entries[index].base_high = (base >> 24) & 0xFF;

            /* Split the limit into its component parts */
            entries[index].limit_low = limit & 0xFFFF;
            entries[index].granularity = (limit >> 16) & 0x0F;

            /* Apply the granularity flags to the upper 4 bits */
            entries[index].granularity |= granularity & 0xF0;

            /* Set the access flags directly */
            entries[index].access = access;
        }

        /*
         * Initializes the Global Descriptor Table for the kernel
         *
         * This sets up a minimal GDT suitable for a 64-bit OS kernel.
         * After setting up the entries, it loads the GDT into the CPU.
         */
        void initialize()
        {
            /* Configure the GDT pointer structure */
            pointer.size = (sizeof(Entry) * 3) - 1; /* Size is one less than actual size (CPU requirement) */
            pointer.address = reinterpret_cast<uint64_t>(&entries);

            /* Entry 0: Required null descriptor (all zeros) */
            set_entry(0, 0, 0, 0, 0);

            /*
             * Entry 1: Kernel code segment for 64-bit mode
             * In long mode, base and limit are ignored for code segments,
             * but we set them anyway for completeness
             */
            set_entry(1, 0, 0xFFFFF,
                      AccessFlags::PRESENT | AccessFlags::DESCRIPTOR_TYPE |
                          AccessFlags::EXECUTABLE | AccessFlags::READ_WRITE,
                      GranularityFlags::LONG_MODE | GranularityFlags::PAGE_GRANULARITY);

            /*
             * Entry 2: Kernel data segment
             * Long mode ignores most segment limits and the SIZE_32BIT flag is not relevant
             */
            set_entry(2, 0, 0xFFFFF,
                      AccessFlags::PRESENT | AccessFlags::DESCRIPTOR_TYPE |
                          AccessFlags::READ_WRITE,
                      GranularityFlags::PAGE_GRANULARITY);

            /* Load the GDT by calling the assembly function */
            load_gdt(&pointer);
        }
    }
}