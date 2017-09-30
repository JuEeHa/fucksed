fucksed
=======
Fucksed is a brainfuck to sed compiler writter in sed.

Usage
-----
The commands to compile and run the compiled code are

	./fucksed.sed < code.b > code.sed
	sed -Ef code.sed

The compiled brainfuck program expects as its input an initial tape in following format:

	66 75 63 6b %73 65 64

Where each two-digit hexadecimal number is one cell and where `%` is prefixed to the cell where the tape head starts off at the start of program execution.

Language support
----------------
At the moment `+-><[]` are supported. There are plants to support `.,` as well in the future

Fucksed uses 8-bit arithmetic with wraparound. This means doing `-` on a cell that has value 00 sets it to ff and doing `+` on a cell that has value ff sets it to 00.

Tape in fucksed is unbounded to the right (meaning you can always > and get more tape). However, doing < at the leftmost cell is underfined and currently a NOP.

Optimizations
-------------
Fucksed does some arithmetic optimizations. A sequence of 16 `+`s or `-`s gets turned into increment/decrement of the more 16s digit. Additionally sequences of length 9 to 15 are expressed in terms of increment/decrement of the 16s digit combined with decrements/increments to get back to the correct result. Subsequent additions and deletions are also handled by one call into the library instead of each operation resulting its own call.

Only construct fucksed optimizes at the moment is `[-]` for memory clear, which would otherwise be a major slowdown due to the unreasonably high overhead of arithmetic.

Error handling
--------------
At the moment fucksed does no error handling. Upon encountering an unknown command (`.` or `,`) or a command that cannot appear at such a position (`]` without matchin `[`) fucksed simply stops processing the program, and outputs the partial compilation.

Portability
-----------
Fucksed uses GNU sed constructs such as '\n'. I'm unsure how they could be avoided and would welcome ideas.

License
-------
All code in this repo is under UNLICENSE / CC0.

`hello.b` is copied from [the Esolang wiki article for brainfuck](https://esolangs.org/wiki/Brainfuck). Esolang wiki uses the CC0 license.
