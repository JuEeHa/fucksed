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

# NOTE: Pitfalls of the inverted character group syntax:
#  [^[]] is interpreted as not '[' plus ]
#  [^][+-<] is interpreted as not '[', ']', or anything in range '+' to '<'

s/[^][<>.,+-]//g

# ------------------------------------------------------
# Preprocessing pass to enable optimizations
# ------------------------------------------------------

# Replace a series of 16 '+'s with a 'p' and 16 '-'s with an 'm'
# They allow for more concise and faster code, as the program can increment/decrement the 16s digit directly

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

# Replace [-] with a zero-out instruction. Since [-] is a common idiom this should give some speedup
s/\[-\]/n/g

# ------------------------------------------------------
# Setting up the pattern space
# ------------------------------------------------------

# Mark the start of the program yet to be compiled with 'bf:'
s/^/bf:/

# Add fields for name generation for branch labels
s/$/\nnext-label:a\nloop-labels:\nreturn-labels:/

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
# \3: contents of loop-labels
# \4: contents of return-labels
# \5: previous sed code

s,^bf:\[(.*)\nnext-label:(.*)\nloop-labels:(.*)\nreturn-labels:(.*)\nsed:(.*),bf:\1\
next-label:\2\
loop-labels:\3 \2\
return-labels:\4\
sed:\5;: \2;/%00/b \2z,

# If we did the previous replacement, we used the value of next-label, so update it
# This "subroutine call" will return back to the top of the loop

t update_next_label

# ]
# Remove the topmost label from the loop-labels stack, since no other ] will match with it
# Generate following sed code:
#  b <label>
#  : <label>z
# It is an unconditional jump to label <label>, which is before the zeroness check
# Additionally, it defines the label <label>z after the loop, which provides a place to jump to exit the loop

# \1: rest of brainfuck code
# \2: contents of next-label
# \3: all but topmost label of the loop-labels stack
# \4: topmost label of the loop-labels stack
# \5: contents of return-labels
# \6: previous sed code

s,^bf:\](.*)\nnext-label:(.*)\nloop-labels:(.*) (\w+)\nreturn-labels:(.*)\nsed:(.*),bf:\1\
next-label:\2\
loop-labels:\3\
return-labels:\5\
sed:\6;b \4;: \4z,

# >
# Generate following sed code:
#  s/%(..) ?(..)?/\1 %\2/
#  s/%$/%00/
# The first replacement moves the '%' which marks the position of the tape head one cell to the right
# In case nothing follows current cell, it results in "<cell> %"
# To extend the tape in such a situation, the second replacement creates a 00 cell if '%' is right against the end of the line

# \1: rest of brainfuck code
# \2: contents of next-label
# \3: contents of loop-labels
# \4: contents of return-labels
# \5: previous sed code

s,^bf:>(.*)\nnext-label:(.*)\nloop-labels:(.*)\nreturn-labels:(.*)\nsed:(.*),bf:\1\
next-label:\2\
loop-labels:\3\
return-labels:\4\
sed:\5;s/%(..) ?(..)?/\\1 %\\2/;s/%\$/%00/,

# <
# Generate following sed code:
#  s/(..) %(..)/%\1 \2/
# It moves the '%' which marks the position of the tape head one cell to the left
# Since our tape is unbounded only to the right, we don't have to deal with extending the tape

# \1: rest of brainfuck code
# \2: contents of next-label
# \3: contents of loop-labels
# \4: contents of return-labels
# \5: previous sed code

s,^bf:<(.*)\nnext-label:(.*)\nloop-labels:(.*)\nreturn-labels:(.*)\nsed:(.*),bf:\1\
next-label:\2\
loop-labels:\3\
return-labels:\4\
sed:\5;s/(..) %(..)/%\\1 \\2/,

# +- (pm+-)
# Add the value of next-label return-labels so that the subroutine return generator knows to generate a return to here
# Generate following sed code:
#  s/%../&<incs or decs>/
#  x
#  s/.*/<label>/
#  b inc_dec
#  : <label>
#  x
# It first puts the list of all the increments/decrements to perform after the current cell
# Afterwards, switch pattern and hold spaces, and replace whatever was in hold space with our label
# This is so that the subroutine we call is able to return to the right place
# The subroutine inc_dec is called to handle the actual incrementation / decrementation
# A label is defined for the subroutine to return to
# Finally the pattern and hold spaces are switched again, since it can't be done by the return trampoline
# This is because the return trampoline needs to perform // on our label, and jumps right after finding the correct one

# \1: the sequence of increments/decrements to perform
# \2: rest of brainfuck code
# \3: contents of next-label
# \4: contents of loop-labels
# \5: contents of return-labels
# \6: previous sed code

# NOTE: Pitfalls of the character group syntax: +-p is considered a range

s,^bf:([pm+-]+)(.*)\nnext-label:(.*)\nloop-labels:(.*)\nreturn-labels:(.*)\nsed:(.*),bf:\2\
next-label:\3\
loop-labels:\4\
return-labels:\5 \3\
sed:\6;s/%\.\./\&\1/;x;s/\.\*/\3/;b inc_dec;: \3;x,

# If we did the previous replacement, we used the value of next-label, so update it
# This "subroutine call" will return back to the top of the loop

t update_next_label

# [-] (n)
# Generate following sed code:
#  s/%../%00/
# It replaces the cell tape head is at with 00, regardless of its value

# \1: rest of brainfuck code
# \2: contents of next-label
# \3: contents of loop-labels
# \4: contents of return-labels
# \5: previous sed code

s,^bf:n(.*)\nnext-label:(.*)\nloop-labels:(.*)\nreturn-labels:(.*)\nsed:(.*),bf:\1\
next-label:\2\
loop-labels:\3\
return-labels:\4\
sed:\5;s/%../%00/,

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

# Stash a copy of the fields into hold space, because subroutine return generator needs it
h

# Remove all but the contents of the sed: field
# FIXME: Do error detection
s/^(.*)^sed://

# Remove the ';' from the beginning of the program
# It was added because all command replacements assume previous code that needs to be suffixed with ';'
s/^;//

# Replace ';' with a newline
# This is to make the program nicer to read and debug
y/;/\n/

# ------------------------------------------------------
# Appending the library routines
# ------------------------------------------------------

# End of main program, print tape and stop executing
s;$;\np\nd\n;

# Handle arithmetic

s;$;: inc_dec\
	# We arrive here with tape in hold space and return label in pattern space, switch them around\
	x\
\
	: inc_dec_loop\
		# %XXp → %X+X, %XXm → %X-X\
		# p and m are increments and decrements for the 16s digit. Converting them makes the code cleaner\
		s/%(.)(.)p/%\\1+\\2/\
		s/%(.)(.)m/%\\1-\\2/\
\
		# +: 0→1→2→3→4→5→6→7→8→9→a→b→c→d→e→f\
		# -: f→e→d→c→b→a→9→8→7→6→5→4→3→2→1→0\
		s/0\\+/1/\
		s/1\\+/2/\
		s/2\\+/3/\
		s/3\\+/4/\
		s/4\\+/5/\
		s/5\\+/6/\
		s/6\\+/7/\
		s/7\\+/8/\
		s/8\\+/9/\
		s/9\\+/a/\
		s/a\\+/b/\
		s/b\\+/c/\
		s/c\\+/d/\
		s/d\\+/e/\
		s/e\\+/f/\
\
		s/f-/e/\
		s/e-/d/\
		s/d-/c/\
		s/c-/b/\
		s/b-/a/\
		s/a-/9/\
		s/9-/8/\
		s/8-/7/\
		s/7-/6/\
		s/6-/5/\
		s/5-/4/\
		s/4-/3/\
		s/3-/2/\
		s/2-/1/\
		s/1-/0/\
\
		# Carry/borrow:\
		# f+ → +0, 0- → -f\
		s/f\\+/+0/\
		s/0-/-f/\
\
		# If carry or borrow moves a + or - right after % (the tape head pointer), remove the + or -\
		# This is because we implement a mod 0xff arithmetic where inc 00 gives ff and dec ff gives 00\
		# %ff+ → %f+0 → %+00\
		# %00- → %0-f → %-ff\
		# Removing the + or - thus implements this mod 0xff arithmetic\
		s/%[+-](..)/%\\1/\
\
		# Run the loop until we have done no replacements\
		t inc_dec_loop\
\
	# Jump into the subroutine return trampoline\
	# It requires the return label to be in pattern space, so switch pattern space and hold space around yet again\
	x\
	b sub_ret\
;

# ------------------------------------------------------
# Generating the code to return from a subroutine
# ------------------------------------------------------

# Switch code to hold space and the saved fields to pattern space
x

# Remove all but the contents of the return-labels: field
# The labels use base-4 counting with "digits" abcd
s/^.*\nreturn-labels:([a-d ]*)\n.*$/\1/

# Replace spaces (separating the labels) with two newlines for easier code generation
# Also add trailing newlines so that every labels is bordered by newlines on both directions
s/$/ /
s/ /\n\n/g

# For every label, generate following sed code:
#  /^<label>$/b <label>

s,\n([a-d ]+)\n,\n/^\1$/b \1\n,g

# Prefix the code with the label "sub_ret"
s,^,: sub_ret,

# Append the generated code to the main program / library routines currently stored in the hold space
H

# Switch the program code back to the pattern space
x

# ------------------------------------------------------
# Finalizing the code
# ------------------------------------------------------

# Remove comments from the code
# NOTE: this doesn't care where in the line # or if it is commented or not
s/\#[^\n]*(\n|$)/\1/g

# Remove indentation from lines
s/(^|\n)[[:space:]]+/\1/g

# Remove empty lines from the code
s/\n{2,}/\n/g
s/^\n|\n$//g
