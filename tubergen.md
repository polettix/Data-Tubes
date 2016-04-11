---
title: 'Data::Tubes'
layout: page
author: polettix
tagline: 'Use the Laziness, Luke!'
comments: true
---

# Tubergen

[tubergen](https://github.com/polettix/Data-Tubes/raw/master/script/tubergen)
is a little program that helps you get up to speed with
[Data::Tubes](https://github.com/polettix/Data-Tubes/). Is't nothing more
than a minting program that allows you to generate (or *mint*) a new
Perl program with *batteries inside*:

- [Data::Tubes](https://metacpan.org/pod/Data::Tubes) different modules and plugins, of course
- [Log::Log4perl::Tiny](https://metacpan.org/pod/Log::Log4perl::Tiny)
- [Template::Perlish](https://metacpan.org/pod/Template::Perlish)
- [Try::Tiny](https://metacpan.org/pod/Try::Tiny)

## Running tubergen

You would normally run it from the command line like in the following
examples:

```
# generate file my-script in current directory
shell$ tubergen -n my-script -A 'this script does that' \
    -a 'A. U. Thor' -e 'a.u.thor@example.com'

# override output filename, e.g. to put in different directory
shell$ tubergen -n my-script -A 'this script does that' \
    -a 'A. U. Thor' -e 'a.u.thor@example.com' \
    -o /path/to/my-script

# you can optionally force setting a different year for copyright
shell$ tubergen -n my-script -A 'this script does that' \
    -a 'A. U. Thor' -e 'a.u.thor@example.com' -y 2020
```

Generating a new program requires you to provide four options at least:

- a *name* for your program;
- an *abstract* to (briefly) describe what your program does;
- the *author* name;
- the *email* of the author.

This allows kickstarting the POD section of your new program. You can
also optionally pass argument *output*, to set the output filename
(which is equal to *name* by default>) and a *year* for the copyright
notice (the current year is used by default).

See the program's manual for a comprehensive description of all options.
You can read it via option `--man`:

```
shell$ tubergen --man
```

## The Minted Program Structure

After you generate the minted program, you end up with a Perl source
file containing the following sections:

- a ["Preamble"](#preamble) with housekeeping that will help get the new program
started with using the included batteries;
- a ["Command Line Handling"](#command-line-handling) section for defining how your program
accepts its inputs;
- a ["Business Logic"](#business-logic) section for putting your code;
- an ["Embedded Modules"](#embedded-modules) section with the _batteries_;
- a ["POD"](#pod) section where you can write the documentation for your new
program.

You will normally need to mind about ["Command Line Handling"](#command-line-handling),
["Business Logic"](#business-logic) and ["POD"](#pod), although it's good for you to know
about all of them. Each part is explained in depth in the sub-sections
below.

### Preamble

The preamble is where the initial setup is done so that you can use
[Data::Tubes](https://metacpan.org/pod/Data::Tubes) and the other embedded modules out of the box. You can
get rid of components you don't need, of course, although you will at
least want to keep the call to `RUSE` for [Data::Tubes](https://metacpan.org/pod/Data::Tubes).

If you need to `use` additional modules, this is probably a good point
to do it. Otherwise, you can just `use` them in the ["Business
Logic"](#business-logic) section, as you see fit.

You will notice that the embedded modules are called through the
function `RUSE`. This trick allows pushing the code below in
["Embedded Modules"](#embedded-modules) so that it does not get in the way of your
program. You are supposed to keep the `RUSE` calls untouched to benefit
from the inclusion of the modules.

You can consider `RUSE` at the same level of a `use` line, though, so
you can add elements in the import list should you need to. For example,
if you need the
["drain" in Data::Tubes](https://metacpan.org/pod/Data::Tubes#drain) you
can modify the relevant `RUSE` line from this:

```
RUSE('Data::Tubes', qw< pipeline summon >);
```

to this:

```
RUSE('Data::Tubes', qw< pipeline summon drain >);
```

You will also notice that the preamble includes the forward-declaration
for all functions in [Try::Tiny](https://metacpan.org/pod/Try::Tiny). This is necessary so that you will be
able to use the syntactic sugar provided by this module. Leave them in
place if you plan to use [Try::Tiny](https://metacpan.org/pod/Try::Tiny), get rid of them (or just ignore
them) otherwise.

### Command Line Handling

Command line handling is performed via [Getopt::Long](https://metacpan.org/pod/Getopt::Long) behind the
scenes. Here you have a simplified interface that should (hopefully) be
what you need most of the times.

Handling of command line is performed by subroutine `get_options`, that
returns a hash (key-value pairs) or hash reference depending on calling
context. In the default section, you get hash `%config` back.

Options are defined as a sequence of elements, each of which can be
either a string or an array reference. The string alternative is exactly
the same as what is accepted by [Getopt::Long](https://metacpan.org/pod/Getopt::Long). The array reference
alternative has the following structure:

- the first element is the [Getopt::Long](https://metacpan.org/pod/Getopt::Long) specification string;
- the following elements are key-value pairs that are put in a hash of
options. Recognised keys are:

    `default`
    :   a default value for the option. This is used to initialize the returned
        hash _before_ the command line is analyzed;

    `fallback`
    :   a default value for the option. This is used to initialize the returned
        hash _after_ the command line is analyzed;

    `required`
    :   this marks whether an option is _required_ or not, set via anything
        that Perl considers _true_ or _false_ depending on your needs. Default
        is _false_.

    The difference between ["default"](#default) and ["fallback"](#fallback) is negligible for
    most options, but you might e.g. set initial values for a
    multiple-valued option (in which case you will want to set it as
    ["default"](#default)) or pass a value that would not be considered good for
    [Getopt::Long](https://metacpan.org/pod/Getopt::Long) (e.g. you cannot pre-initialize options with GLOBs, in
    which case you would choose ["fallback"](#fallback)). In general, use ["default"](#default)
    unless you really need ["fallback"](#fallback).

The newly minted program contains a few examples to get you started. You
might want to keep the first one on `loglevel` though, as it will help
you set the logging level of the script automatically.

### Business Logic

This is where your business logic is supposed to be written, which is
only yours. A couple of considerations are worth mentioning though:

- functions from [Try::Tiny](https://metacpan.org/pod/Try::Tiny) have their prototype declared in the
["Preamble"](#preamble), but all other `RUSE`d functions are available at runtime
but unknown at compile time. This means that you will need to use
parentheses to call them (which is somehow different from all examples
in [Log::Log4perl::Tiny](https://metacpan.org/pod/Log::Log4perl::Tiny), for example);
- apart from the modules `use`d/`RUSE`d in the ["Preamble"](#preamble), other
modules are directly `use`d by the program, e.g. [Pod::Usage](https://metacpan.org/pod/Pod::Usage) and
[Getopt::Long](https://metacpan.org/pod/Getopt::Long) in the ["Embedded Modules"](#embedded-modules) section or in the embedded
modules themselves.

### Embedded Modules

Your business logic is supposed to live in section ["Business Logic"](#business-logic),
so you should generally not need to put anything here.

This section contains most of the _batteries included_. It has the
options parsing function `get_options`, the _require-as-use_ function
`RUSE`, the logic for embedding all modules.

If you want to embed additional pure-Perl modules, and `RUSE` them, you
are welcome to do this. Just follow the example of the other modules,
namely:

- add items inside the hash `%file_for` defined at the top of the
`BEGIN` section;
- each item's key is a relative file name of the module, as if it was in
some `lib` directory (see shipped modules for an example);
- each item's value is a string with the whole contents of your module,
where each line is pre-pended with a single space character (ASCII
0x20). This character will be automatically removed and allows you to
safely use here-documents, again see the included modules for an
effective example;
- although not strictly necessary, for your convenience you might want to
keep the relative position of different comment markers starting with
string `__MOBUNDLE__`.

Example:

```
BEGIN {
   my %file_for = (

# __MOBUNDLE_FILES__

# __MOBUNDLE_FILE__

   # this is for embedding Some::Module. Note that the
   # contents of the heredoc is indented by one space at
   # each line
   "Some/Module.pm" => <<'END_OF_FILE';
␠#
␠# Some::Module contents, each line is indented by one space
␠# so that e.g. the following lines will not mess all things
␠# up:
␠my $something = <<'END_OF_FILE'
␠What...ever!
␠END_OF_FILE
␠# The line above is indented, so it is ignored by the
␠# program's heredoc. The real boundary for the included
␠# module is the line below.
END_OF_FILE

# __MOBUNDLE_FILE
#
# ... REST OF %file_for hash...
```

### POD

This is where you are supposed to write _extensive_ documentation for
your new program. There's some scaffolding to get you started,
initialized with the required values provided during the minting
process. [perlpod](https://metacpan.org/pod/perlpod) will be your friend
here.

The generated POD documentation also includes a note about all includes
modules, with their copyright and references. You are supposed to keep
them in order to give due credits.

## Final Remarks

[tubergen](https://github.com/polettix/Data-Tubes/raw/master/script/tubergen)
is a way to get started using
[Data::Tubes](https://github.com/polettix/Data-Tubes/) quickly and
without too much hassle, as the program it generates will be
self-contained (well, depending on how you code your business logic, at
least). This is probably what you want most of the times... so it's good
for you to know about it!
