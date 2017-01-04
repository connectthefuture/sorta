Sorta-sane Parameter Handling in Bash
=====================================

Requires Bash 4.3 or higher.

So Bash (hereafter, "bash") doesn't let you pass anything other than
string literals, not even variables (if you ask it to, it expands
variables to strings and then passes those).

That makes it a tricky language to work with any kind of structured
datatype. It's not even pretty when you're just passing strings.

Sorta is a library that lets you:

-   pass scalar values by variable name instead of using expansions

-   pass arrays literals or by variable name

-   pass hashes literals or by variable name

-   return arrays

-   return hashes

-   specify default values for parameters

-   expand hash keys into local variables

For example, let's say you have a couple data structures:

    declare -A myhash=([this]=that [humpty]=dumpty)
    declare -a myarray=( one two three )

and you want to pass some of the values to a function:

    my_function "${myhash[humpty]}" "${myarray[2]}"

With sorta, you can call it with this instead:

    my_function myhash[humpty] myarray[2]

by adding this to the beginning of `my_function`:

    local _params=( first_arg second_arg )
    eval "$(passed _params "$@")"

In that scenario, `first_arg` will get "dumpty", `second_arg` will get
"three".

That may be nice, but it's not anything you can't already do in bash.

How about passing a hash and an array directly by name:

    my_function myhash myarray

You can do this with sorta by adding special type designators to the
`_params` list:

    local _params=( %hash @array )

Your dad's bash can't do that easily.

(note that `hash` and `array` could be any variable names, I'm just
using those names for clarity)

Installation
============

Clone this repository and place it's `lib` directory on your path.

In your scripts you can then use `source sorta.bash` and it will be
found automatically.

Usage
=====

Pass Scalar Values (strings)
----------------------------

To write a function which receives variables this way, you need to
declare a local array of parameter names/types, then eval the output of
the `passed` function:

    source sorta.bash

    my_function() {
      local _params=( first second )
      eval "$(passed _params "$@")"

      echo 'first: '"$first"
      echo 'second: '"$second"
    }

Outputs:

    $ my_function 1 2
    first: 1
    second: 2

Similarly, you can call it with variable names:

    $ myvar1=one
    $ myvar2=two
    $ my_function myvar1 myvar2
    first: one
    second: two

Notice that no expansion was needed for the variable names. Of course,
that will still work:

    $ my_function "$myvar1" "$myvar2"
    first: one
    second: two

But that's because the expansion happens prior to the function call,
making this case the same as the first example which called
`my_function` with literals.

You can also index arrays and hashes when supplying scalars:

    $ array=( 1 2 )
    $ my_function array[0] array[1]
    first: 1
    second: 2

    $ declare -A hash=( [one]=1 [two]=2 )
    $ my_function hash[one] hash[two]
    first: 1
    second: 2

Set Default Values
------------------

Like most high-level languages, setting a default value for a parameter
allows you to not pass that argument into the function. In that case,
the parameter will be automatically set to the default value. Like most
implementations, any default-valued parameters have to come in a
contiguous set on the end of the definition:

    source sorta.bash

    my_function2() {
      local _params=( first=1 )
      eval "$(passed _params "$@")"

      echo 'first: '"$first"
    }

Outputs:

    $ my_function2 one
    first: one

    $ my_function2
    first: 1

Note that supplying an empty string overrides the default:

    $ my_function2 ''
    first:

That means calling `my_function2 "$myvar"`, where `myvar` is empty or
unset, is different from calling `my_function2` without an argument.
Caller beware.

Pass Arrays
-----------

Arrays can be passed by name or by literal value. It is passed by value,
so the receiving function operates on a copy of the array, not a
reference to the original.

To receive an array, a parameter is simply prefixed with an "@" which
symbolizes the expected type but naturally does not become part of the
variable name:

    source sorta.bash

    my_function3() {
      local _params=( @first )
      eval "$(passed _params "$@")"

      declare -p first
    }

`declare -p` shows you bash's conception of the variable:

    $ array=( 1 2 )
    $ my_function3 array
    declare -a first='([0]="1" [1]="2")'

This shows that the function received an array with the desired values
and assigned it to `first`.

To pass a literal, use the same syntax as an array assignment, simply
without the left-hand side:

    $ my_function3 '( 1 2 )'
    declare -a first='([0]="1" [1]="2")'

You can use any syntax that an assignment accepts, indexed or
non-indexed.

Pass Hashes
-----------

Hashes, or associative arrays, are much the same as arrays, just
specified with a "%" (thanks, Perl) rather than an "@":

    source sorta.bash

    my_function4() {
      local _params=( %first )
      eval "$(passed _params "$@")"

      declare -p first
    }

    $ declare -A hash=( [one]=1 [two]=2 ) # hashes require a "declare -A"
    $ my_function4 hash
    declare -A first='([one]="1" [two]="2" )'

Literals work much the same but require the indices:

    $ my_function4 '([one]=1 [two]=2)'
    declare -A first='([one]="1" [two]="2" )'

Be careful to quote the values of your key-value pairs if they contain
spaces.

Return Arrays and Hashes
------------------------

Returning scalars from functions doesn't require any special syntax
since you can already do this in bash:

    do_something_with "$(echo "a string returned by echo")"

Returning arrays and hashes isn't natively supported by bash however.
With sorta, you can write your functions to return a special form:

    source sorta.bash

    my_function5() {
      local array=( 1 2 )
      pass array
    }

The "special form" is just a declaration string actually. But with a
little bit of help from another function, you can get it back into your
namespace thusly:

    $ eval "$(assign myarray "$(my_function5)")"
    $ declare -p myarray
    declare -a myarray='([0]="1" [2]="2")'

Now the array passed by `my_function5` is an array in your scope, under
the variable name you chose with sorta's `assign` function.

Notice `my_function5` was called with the normal shell substitution
parentheses around it to get the string it was returning.

Hashes are passed back the same way, by name. There's no special syntax
for dealing with arrays differently from hashes, they're treated the
same.

Expand Hash Keys into Local Variables
-------------------------------------

Now that hashes can be passed around, it can be handy to pass a hash to
a function and then import key-value pairs from that hash into the local
namespace:

    source sorta.bash

    my_function6() {
      local _params=( %myhash )
      eval "$(passed _params "$@")"
      eval "$(froms myhash one)"
      echo 'one: '"$one"
    }

Outputs:

    $ declare -A hash=( [one]=1 )
    $ my_function6 hash
    one: 1

`froma` takes an array of key names:

    source sorta.bash

    my_function7() {
      local _params=( %myhash )
      eval "$(passed _params "$@")"
      eval "$(froma myhash '( one two three )')"
      echo 'one: '"$one"
      echo 'two: '"$two"
      echo 'three: '"$three"
    }

Outputs:

    $ declare -A hash=( [one]=1 [two]=2 [three]=3 )
    $ my_function7 hash
    one: 1
    two: 2
    three: 3

`fromh` does the same as `froma` but uses a hash mapping to specify the
names of the variables to expand the keys to:

    source sorta.bash

    my_function8() {
      local _params=( %myhash )
      eval "$(passed _params "$@")"
      eval "$(fromh myhash '( [one]=singing [two]=inthe [three]=rain )')"
      echo 'singing: '"$singing"
      echo 'inthe: '"$inthe"
      echo 'rain: '"$rain"
    }

Outputs:

    $ declare -A hash=( [one]=1 [two]=2 [three]=3 )
    $ my_function8 hash
    singing: 1
    inthe: 2
    rain: 3

Future: `assigna` will be provided to allow the mass reassignment of
variable names expanded from a hash a la:

    $ eval "$(assigna '( new_one new_two )' "$(fromh myhash '( one two )')")"
    $ echo "$new_one"
    myhash[one]'s value
    $ echo "$new_two"
    myhash[two]'s value
