# NAME

Data::Tubes - Text and data canalising

# VERSION

This document describes Data::Tubes version 0.01.

# SYNOPSIS

    use Data::Tubes qw< drain summon >;

    # load components from relevant plugins
    summon(
       qw<
          +Plumbing::sequence
          +Source::iterate_files
          +Reader::read_by_line
          +Parser::parse_hashy
          +Renderer::render_with_template_perlish
          +Writer::write_to_files
          >
    );

    # define a sequence of tubes, they're just a bunch of sub references
    my $sequence = sequence(
       iterate_files(files => [\"n=Flavio|q=how are you\nn=X|q=Y"]),
       read_by_line(),
       parse_hashy(chunks_separator => '|'),
       render_with_template_perlish(template => "Hi [% n %], [% q %]?\n"),
       write_to_files(filename => \*STDOUT),
    );

    # run it, forget about what comes out of the end
    drain($sequence);

# DESCRIPTION

This module allows you to define _Tubes_, which are little more than
transformation subroutines over records.

# FUNCTIONS

- **drain**

        drain($tube, @tube_inputs);

    drain whatever comes out of a tube. The tube is run with the provided
    inputs, and if an iterator comes out of it, it is repeatedly run until
    it provides no more output records.

- **summon**

        # Direct function import
        summon('Some::Package::subroutine');

        # DWIM, treat 'em as plugins under Data::Tubes::Plugin
        summon(
           {
              '+Source' => [ qw< iterate_array open_file > ],
           },
           [ qw< +Plumbing sequence logger > ],
           '+Reader::read_by_line',
        );

    summon operations, most likely from plugins.  This is pretty much the
    same as a regular `import` done by `use`, only supposed to be easier
    to use in a script.

    You can pass different things:

    - _array_

        the first item in the array will be considered the package name, the
        following ones sub names inside that package;

    - _hash_

        each key will be considered a package name, pointing to either a string
        (considered a sub name) or an array (each item considered a sub name);

    - _string_

        this will be considered a fully qualified sub name, i.e. including the
        package name at the beginning.

    In every case, if the package name starts with a `+` plus sign, the
    package name will be considered relative to `Data::Tubes::Plugin`, so
    the `+` plus sign will be substitued with `Data::Tubes::Plugin::`. For
    example:

        +Plumbing becomes Data::Tubes::Plugin::Plumbing
        +Reader   becomes Data::Tubes::Plugin::Reader

    and so on.

    It's probable that the `import` method will be overridden to make this
    import easy directly upon `use`-ing this module, instead of explicitly
    calling `summon`.

# BUGS AND LIMITATIONS

Report bugs either through RT or GitHub (patches welcome).

# AUTHOR

Flavio Poletti <polettix@cpan.org>

# COPYRIGHT AND LICENSE

Copyright (C) 2016 by Flavio Poletti <polettix@cpan.org>

This module is free software. You can redistribute it and/or modify it
under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.
