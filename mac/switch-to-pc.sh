#!/bin/sh
# Switch both BenQ PD2506Q monitors to the PC (DisplayPort = input 15).
# Needs m1ddc (Apple Silicon):  brew install m1ddc
# Used as the "Run Shell Script" action in a Shortcuts shortcut bound to a hotkey.
/opt/homebrew/bin/m1ddc display 1 set input 15
/opt/homebrew/bin/m1ddc display 2 set input 15
