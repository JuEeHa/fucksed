#!/bin/sed -Ef

# By nortti (2017), under Unlicense / CC0

# ------------------------------------------------------
# Input initialization
# ------------------------------------------------------

# Read the entirety of the program into memory
: read
$b read_done
N
b read
: read_done

# Strip out non-command characters (including whitespace)
# Pitfalls of the inverted character group syntax:
# [^[]] is interpreted as not '[' plus ]
# [^][+-<] is interpreted as not '[', ']', or anything in range '+' to '<'
s/[^][<>.,+-]//g

# Mark the start of the program yet to be compiled with 'bf:'
s/^/bf:/

# Add fields for name generation for branch labels
s/$/\nnext-label:a\nlabels:/

# Add a field for the resultant sed code
s/$/\nsed:/

# ------------------------------------------------------
# Compiler main loop
# ------------------------------------------------------

: mainloop

# [
# Append the value of next-label to the stack of labels, such that the next ] can find it
# Generate following sed code:
#  : <label>
#  /%00/b <label>b
# It is a conditional jump to the label <label>b, which is used for the one after the loop body
# Jumping there exits the loop
# Additionally, it defines the label <label> before the conditional jump, so that ] can jump back here

# \1: rest of brainfuck code
# \2: contents of next-label
# \3: contents of labels
# \4: previous sed code

s,^bf:\[(.*)\nnext-label:(.*)\nlabels:(.*)\nsed:(.*),bf:\1\
next-label:\2a\
labels:\3 \2\
sed:\4;: \2;/\%00/b \2b,

# ]
# Remove the topmost label from the labels stack, since no other ] will match with it
# Generate following sed code:
#  b <label>
#  : <label>b
# It is an uncoditional jump to label <label>, which is before the zeroness check
# Additionally, it defines the label <label>b after the loop, which provides a place to jump to exit the loop

# \1: rest of brainfuck code
# \2: contents of next-label
# \3: all but topmost label of the stack
# \4: topmost label of the stack
# \5: previous sed code

s,^bf:\](.*)\nnext-label:(.*)\nlabels:(.*) (\w+)\nsed:(.*),bf:\1\
next-label:\2\
labels:\3\
sed:\5;b \4;: \4b,

# >
# Generate following sed code:
#  s/\%(..) ?(..)?/\1 \%\2/
#  s/\%$/\%00/
# The first replacement moves the '%' which marks the position of the tape head one cell to the right
# In case nothing follows current cell, it results in "<cell> %"
# To extend the tape in such a situation, the second replacement creates a 00 cell if '%' is right against the end of the line

# \1: rest of brainfuck code
# \2: contents of next-label
# \3: contents of labels
# \4: previous sed code

s,^bf:>(.*)\nnext-label:(.*)\nlabels:(.*)\nsed:(.*),bf:\1\
next-label:\2\
labels:\3\
sed:\4;s/\\\%(..) ?(..)?/\\1 \\\%\\2/;s/\\\%\$/\\\%00/,

# <
# Generate following sed code:
#  s/(..) \%(..)/\%\1 \2/
# It moves the '%' which marks the position of the tape head one cell to the left
# Since our tape is unbounded only to the right, we don't have to deal with extending the tape

# \1: rest of brainfuck code
# \2: contents of next-label
# \3: contents of labels
# \4: previous sed code

s,^bf:<(.*)\nnext-label:(.*)\nlabels:(.*)\nsed:(.*),bf:\1\
next-label:\2\
labels:\3\
sed:\4;s/(..) \\\%(..)/\\\%\\1 \\2/,

# TODO: +-
# TODO: .
# TODO: ,

# Repeat mainloop as long as we have done a replacement
# Assumes that lack of a replacement means there is nothing left to compile
# FIXME: Do error detection
t mainloop

# ------------------------------------------------------
# Printing the resulting code
# ------------------------------------------------------

# Remove all but the contents of the sed: field
# FIXME: Do error detection
s/^(.*)^sed://

# Remove the ';' from the beginning of the program
# It was added because all command replacements assume previous code that needs to be suffixed with ';'
s/^;//

# Replace ';' with a newline
# This is to make the program nicer to read and debug
y/;/\n/
