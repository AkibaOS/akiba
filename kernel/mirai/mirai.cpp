#include <core/terminal.hpp>
#include <arch/gdt.hpp>

extern "C" void Mirai()
{
    // First, initialize the GDT
    AkibaOS::GDT::initialize();

    // Then initialize terminal
    AkibaOS::Terminal::initialize();

    // Set colors and display welcome message
    AkibaOS::Terminal::set_color(AkibaOS::Terminal::Color::Cyan, AkibaOS::Terminal::Color::Black);
    AkibaOS::Terminal::print_string("Welcome to AkibaOS!\n");

    AkibaOS::Terminal::set_color(AkibaOS::Terminal::Color::Yellow, AkibaOS::Terminal::Color::Black);
    AkibaOS::Terminal::print_string("Drifting from abyss towards the infinite!\n");

    AkibaOS::Terminal::set_color(AkibaOS::Terminal::Color::Magenta, AkibaOS::Terminal::Color::Black);
    AkibaOS::Terminal::print_string("===============================================\n");

    AkibaOS::Terminal::set_color(AkibaOS::Terminal::Color::White, AkibaOS::Terminal::Color::Black);
    AkibaOS::Terminal::print_string("System initialized and ready.\n");
}