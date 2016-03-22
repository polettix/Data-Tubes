# NAME

Text::Tubes - Text and data canalising

# VERSION

This document describes Text::Tubes version 0.01.

# SYNOPSIS

    use Text::Tubes;

# DESCRIPTION

This module allows you to define _Tubes_, which are little more than
transformation subroutines over records.

# FUNCTIONS

- **loglevel**

        loglevel('DEBUG');

    set the log level, see [Log::Log4perl::Tiny](https://metacpan.org/pod/Log::Log4perl::Tiny).

- **sequence**

        my $sequence_sub = sequence(@subs_or_tubes);
        my $iterator = $sequence_sub->($some_record);
        1 while defined $iterator->(); # not interested in outputs...

        my $seq_tube = tube(my_sequence => $sequence_sub);
        my $it = $seq_tube->operate($some_other_record);
        # use $it to extract outputs from the sequence

    create a sequence of tubes.

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
