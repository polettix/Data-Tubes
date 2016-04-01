---
title: 'Data::Tubes'
layout: page
author: 'polettix'
tagline: 'Text and data canalising'
---

Some input in `data.txt`:

```
name=Flavio|age=44|food=salad
food=banana|name=FooBar|age=29
age=52|name=What Ever|food=kiwi
```

Something to fill in `template.tp`:

```
---------------------------------------------------------------
Hi [% name %]! Happy birthday, now you are [% age %] years old!
Would you like a [% food %]?
_______________________________________________________________
```

The code to merge them:

```perl
use Data::Tubes qw< pipeline >;

# slurp the template
my $template = do { local (@ARGV, $/) = ('template.tp'); <> };

# build a pipeline with a sequence of "tubes", each doing
# its own specific job like reading, parsing, rendering...
my $pl = pipeline(
   'Source::iterate_files',
   'Reader::by_line',
   ['Parser::hashy', chunks_separator => '|'],
   ['Renderer::with_template_perlish', template => $template],
   ['Writer::to_files', filename => \*STDOUT],
   {tap => 'sink'}
);

$pl->(['data.txt']);
```
