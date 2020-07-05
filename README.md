This is Elko, a simplistic coroutine system for C that I wrote back in 2018 and never released for some reason. I didn't document it at the time, so this README contains some genuine code archaeology.

Warning! Elko is hacky and unsophisticated and blunt and fragile! It barely works! Why are you trying to use this? No, put the cream pie down!

# The Compiler

Usage is simple. Trivial, even. (If you have Lua 5.3.)

```sh
elko.lua input.elko -o output.c
```

This compiles the Elko source file `input.elko` into the C source file `output.c`. There are no other options. The resulting source file ~~can~~ should be compilable on any C compiler that would compile the non-elkoish parts of your code.

# The Language

In C, a subroutine normally has a single parameter list, and returns once:

```c
int sum(int a, int b) {
  return a + b;
}
```

Elko adds a special kind of subroutine, an `elkoroutine`. It has two parameter lists: an initial parameter list and a continue parameter list.

```c
elkoroutine int running_sum(int starting_value)(int next_addition) {
  int current_value = starting_value;
  while(1) {
    current_value += next_addition;
    return current_value;
  }
}
```

An `elkoroutine` is introduced by the eponymous keyword. This keyword can be preceded by `static` to limit linkage to the current translation unit (as with ordinary routines), but then it *cannot be forward declared*.

The above `elkoroutine` produces the following three C elements:

```c
union running_sum_state;
void running_sum_init(union running_sum_state*, int starting_value);
int running_sum(union running_sum_state*, int next_addition);
```

`NAME_init()` takes the initial parameter list and always returns `void`. `NAME()` takes the continue parameter list and returns whatever the `elkoroutine`'s return type is (in this case `int`). `union NAME_state` is where `NAME()`'s temporary variables live instead of being pushed on the program stack.

Calling `NAME_init()` initializes the `NAME_state` for the beginning of the routine, populating any initial parameters with the provided values. You then call `NAME()` as many times as you like. The first time you call, it will start from the beginning. For each subsequent call, `NAME()` will resume from where it left off.

```c
int main() {
  union running_sum_state state;
  running_sum_init(&state, -17);
  printf("%i\n", running_sum(&state, 7)); // prints -10
  printf("%i\n", running_sum(&state, 24)); // prints 14
  printf("%i\n", running_sum(&state, -5)); // prints 9
  return 0;
}
```

Importantly, *none of the body* of the `elkoroutine` is in the `init` function. The actual code only begins to run the first time you call the continuation routine.

This example had only two continuation points: the start of the body, and one within the loop. An `elkoroutine` can have arbitrarily many `return`s, and each one creates a new continuation point. Also, you can have as many or as few parameters in each of the two parameter lists as you like.

Other than `elkoroutines`, an Elko source file is ordinary C code. The compiler reads Elko code and outputs pure C code, with no support library or additional work needed. This C code will compile on any compiler that understands the C parts of your code.

# Caveats

- You can't give a variable in an `elkoroutine` a name starting with `_elko`. Identifiers like that are reserved for Elko's use.
- Be careful letting execution reach the end of an `elkoroutine`. Execution will return to the beginning of the routine if that occurs, with any init-parameters still retaining possibly changed values.
- **Don't return from inside a `switch` statement in an `elkoroutine`.** If you try, you'll get behavior you don't want and/or a compiler error.
- **Don't use macros to generate `elkoroutine`s, variable declarations within `elkoroutines`, or yielding `return`s.** Also be careful with `#if`. Elko sees the code before macro expansion and other preprocessor activity. (If you use the preprocessor conservatively, Elko should still be able to make sense of your code.)
- Other stuff will break. Remember the warning above about it being fragile?

# Practical Use

I recommend confining elkoroutines to one file, or a few files. Bearing in mind that the following Elko source:

```c
elkoroutine A foo(B bar)(C baz) {
  ...
}
```

generates the following C source:

```c
union foo_state;
void foo_init(union foo_state*, B bar) { ... }
A foo(union foo_state*, C baz) { ... }
```

You can put the following in a header:

```c
union foo_state;
void foo_init(union foo_state*, B bar);
A foo(union foo_state*, C baz);
union foo_state* foo_alloc();
```

And add the following after the `elkoroutine` in the Elko file:

```c
union foo_state* foo_alloc() {
  return calloc(sizeof(union foo_state), 1);
}
```

(since only that file will know the exact size of `union foo_state`)

Then you can access the `elkoroutine` from other source files, and not have to worry about Elko getting confused by the preprocessor or by peculiar C syntax or just by getting looked at the wrong way because did I mention it's fragile?

# Nesting

You should be able to call `elkoroutine`s from other `elkoroutine`s, as long as you handle them the same way you would from C. No support for "transparently embedded" `elkoroutine`s—what would the parent return when the child resumed?

# Legalese

Copyright ©2018-2020 Solra Bizna.

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.

Note: It is *not* my intention that your use of Elko infect code that you write or transpile with it. **Elko's license applies only to the Elko transpiler itself, and _NOT_ to its output!**

Note 2: This copyright notice and license statement are present in `elko.lua` and in the first source file it is concatentated from, but omitted from the others to keep from inflating the final script. **Unless otherwise specified at the top of a given file, Elko's license and copyright apply to all source files in this repository, even those that appear to lack any license statement!**

