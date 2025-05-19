#pragma once

#include <cstdint>
#include <cstddef>

namespace AkibaOS
{
    namespace Terminal
    {
        // VGA color constants
        enum class Color : uint8_t
        {
            Black = 0,
            Blue = 1,
            Green = 2,
            Cyan = 3,
            Red = 4,
            Magenta = 5,
            Brown = 6,
            LightGray = 7,
            DarkGray = 8,
            LightBlue = 9,
            LightGreen = 10,
            LightCyan = 11,
            LightRed = 12,
            Pink = 13,
            Yellow = 14,
            White = 15
        };

        // Create a VGA entry color from foreground and background
        constexpr uint8_t make_color(Color fg, Color bg)
        {
            return static_cast<uint8_t>(fg) | (static_cast<uint8_t>(bg) << 4);
        }

        // Initialize terminal
        void initialize();

        // Clear the terminal
        void clear();

        // Set color
        void set_color(Color fg, Color bg);

        // Print methods
        void print_char(char character);
        void print_string(const char *string);
        void print_newline();
    }
}