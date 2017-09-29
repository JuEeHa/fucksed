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

# ------------------------------------------------------
# Preprocessing pass to enable optimizations
# ------------------------------------------------------

# Replace a series of 16 '+'s with a 'p' and 16 '-'s with an 'm'
# They allow for more conscice and faster code, as the program can increment/decrement the 16s digit directly

s/\+{16}/p/g
s/\-{16}/m/g

# Express increment / decrement of 9…15 in terms of 'p' or 'm' and then '-' or '+' to bring it back to the right value
# For example, 15 makes more sense to write as 'p-' than '+++++++++++++++'
# This works because arithmetic wraps around

s/\+{15}/p-/g
s/\+{14}/p--/g
s/\+{13}/p---/g
s/\+{12}/p----/g
s/\+{11}/p-----/g
s/\+{10}/p------/g
s/\+{9}/p-------/g

s/\-{15}/m+/g
s/\-{14}/m++/g
s/\-{13}/m+++/g
s/\-{12}/m++++/g
s/\-{11}/m+++++/g
s/\-{10}/m++++++/g
s/\-{9}/m+++++++/g

# ------------------------------------------------------
# Setting up the pattern space
# ------------------------------------------------------

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
#  /%00/b <label>z
# It is a conditional jump to the label <label>z, which is used for the one after the loop body
# Jumping there exits the loop
# Additionally, it defines the label <label> before the conditional jump, so that ] can jump back here

# \1: rest of brainfuck code
# \2: contents of next-label
# \3: contents of labels
# \4: previous sed code

s,^bf:\[(.*)\nnext-label:(.*)\nlabels:(.*)\nsed:(.*),bf:\1\
next-label:\2\
labels:\3 \2\
sed:\4;: \2;/\%00/b \2z,

# If we did the previous replacement, we used the value of next-label, so update it
# This "subroutine call" will return back to the top of the loop

t update_next_label

# ]
# Remove the topmost label from the labels stack, since no other ] will match with it
# Generate following sed code:
#  b <label>
#  : <label>z
# It is an uncoditional jump to label <label>, which is before the zeroness check
# Additionally, it defines the label <label>z after the loop, which provides a place to jump to exit the loop

# \1: rest of brainfuck code
# \2: contents of next-label
# \3: all but topmost label of the stack
# \4: topmost label of the stack
# \5: previous sed code

s,^bf:\](.*)\nnext-label:(.*)\nlabels:(.*) (\w+)\nsed:(.*),bf:\1\
next-label:\2\
labels:\3\
sed:\5;b \4;: \4z,

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

# Jump over the utility functions into where we print out the compiled program
b print

# ------------------------------------------------------
# Utility functions
# ------------------------------------------------------

# Update the next-label counter
: update_next_label
	# Add ' to the end of the label, to mark that it's going to be incremented by one
	# Labels are base 4 and only use the "digits" abcd
	s/(\nnext-label:[abcd]+)\n/\1'\n/

	: update_next_label_loop
		# a→b→c→d
		s/(\nnext-label:[abcd]*)a'/\1b/
		s/(\nnext-label:[abcd]*)b'/\1c/
		s/(\nnext-label:[abcd]*)c'/\1d/

		# After d gets incremented, we go back to a and increment the next digit
		s/(\nnext-label:[abcd]*)d'/\1'a/

		# If we have a ' right at the beginning of the next-label field, add a new 'a'
		s/(\nnext-label:)'/\1a/

		# Run the loop until no new replacements happened (at which point we've done all replacements we can)
		t update_next_label_loop

	# Return to the compiler main loop
	b mainloop

# ------------------------------------------------------
# Printing the resulting code
# ------------------------------------------------------

: print

# Remove all but the contents of the sed: field
# FIXME: Do error detection
s/^(.*)^sed://

# Remove the ';' from the beginning of the program
# It was added because all command replacements assume previous code that needs to be suffixed with ';'
s/^;//

# Replace ';' with a newline
# This is to make the program nicer to read and debug
y/;/\n/
