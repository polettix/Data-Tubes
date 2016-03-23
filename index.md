---
title: 'Data::Tubes'
layout: page
author: 'polettix'
tagline: 'Text and data canalising'
---

```perl
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
   tubes => [
      iterate_files(files => [\"n=Flavio|q=how are you\nn=X|q=Y"]),
      read_by_line(),
      parse_hashy(chunks_separator => '|'),
      render_with_template_perlish(template => "Hi [% n %], [% q %]?\n"),
      write_to_files(filename => \*STDOUT),
   ],
);

# run it, forget about what comes out of the end
drain($sequence);
```
