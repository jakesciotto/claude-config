#!/bin/bash

# CREDIT: https://github.com/holman/dotfiles/blob/master/macos/set-defaults.sh

# Always open everything in Finder's list view. This is important.
defaults write com.apple.Finder FXPreferredViewStyle Nlsv

# Show the ~/Library folder.
chflags nohidden ~/Library

# Show hidden files in Finder.
defaults write com.apple.finder AppleShowAllFiles -bool true