#include "include/terminal.hpp"

namespace AkibaOS
{
    namespace Terminal
    {
        // Constants
        constexpr size_t VGA_WIDTH = 80;
        constexpr size_t VGA_HEIGHT = 25;

        // VGA buffer character structure
        struct VGAChar
        {
            uint8_t character;
            uint8_t color;
        };

        // Terminal state
        VGAChar *const buffer = reinterpret_cast<VGAChar *>(0xB8000);
        size_t column = 0;
        size_t row = 0;
        uint8_t current_color;

        // Clear a specific row
        void clear_row(size_t row_num)
        {
            const VGAChar empty = {
                ' ',
                current_color};

            for (size_t col = 0; col < VGA_WIDTH; col++)
            {
                buffer[col + VGA_WIDTH * row_num] = empty;
            }
        }

        // Initialize the terminal
        void initialize()
        {
            current_color = make_color(Color::White, Color::Black);
            clear();
        }

        // Clear the entire terminal
        void clear()
        {
            for (size_t row_num = 0; row_num < VGA_HEIGHT; row_num++)
            {
                clear_row(row_num);
            }
            column = 0;
            row = 0;
        }

        // Set the current color
        void set_color(Color fg, Color bg)
        {
            current_color = make_color(fg, bg);
        }

        // Handle newline
        void print_newline()
        {
            column = 0;

            // If we have space, just move to the next row
            if (row < VGA_HEIGHT - 1)
            {
                row++;
                return;
            }

            // Otherwise, scroll the terminal
            for (size_t y = 1; y < VGA_HEIGHT; y++)
            {
                for (size_t x = 0; x < VGA_WIDTH; x++)
                {
                    buffer[x + VGA_WIDTH * (y - 1)] = buffer[x + VGA_WIDTH * y];
                }
            }

            // Clear the last row
            clear_row(VGA_HEIGHT - 1);
        }

        // Print a character
        void print_char(char c)
        {
            if (c == '\n')
            {
                print_newline();
                return;
            }

            // Handle line wrap
            if (column >= VGA_WIDTH)
            {
                print_newline();
            }

            // Write the character to the buffer
            buffer[column + VGA_WIDTH * row] = {
                static_cast<uint8_t>(c),
                current_color};

            column++;
        }

        // Print a string
        void print_string(const char *str)
        {
            for (size_t i = 0; str[i] != '\0'; i++)
            {
                print_char(str[i]);
            }
        }
    }
}