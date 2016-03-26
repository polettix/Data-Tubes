---
title: 'Data::Tubes'
layout: page
author: 'polettix'
tagline: 'Text and data canalising'
---

```perl
use Data::Tubes qw< pipeline >;
my $pl = pipeline(
   'Source::iterate_files',
   'Reader::by_line',
   ['Parser::hashy', chunks_separator => '!'],
   ['Renderer::with_template_perlish',
    template => "Hi [% n %], [% q %]?\n"],
   ['Writer::to_files', filename => \*STDOUT],
   { tap => 'sink' }
);

# iterate_files takes an array reference with file "names"
# or handles inside. Here a reference to a string will do
# as a file name
$pl->([\"n=Flavio|q=how are you\nn=X|q=Y"]); ```
```
