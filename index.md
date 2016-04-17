---
title: 'Data::Tubes'
layout: page
author: 'polettix'
tagline: 'Text and data canalising'
comments: false
---

# Welcome

[Data::Tubes](https://metacpan.org/pod/Data::Tubes) helps you manage
transformations steps on a stream of data that can be though as a sequence
of _records_. It does it by passing _records_ through _tubes_, usually a
sequence of them.

What a *record* is and what each *tube* does can be entirely up to you.
There's a toolkit, though, that will help you with some common cases for
reading, parsing, rendering and writing records. Find a few examples
below, and the full story in [the manual](manual).

## Getting Your Feet Wet

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

# build a pipeline with a sequence of "tubes", each doing
# its own specific job like reading, parsing, rendering...
my $pl = pipeline(
   'Source::iterate_files',
   'Reader::by_line',
   ['Parser::hashy', chunks_separator => '|'],
   ['Renderer::with_template_perlish', ['template.tp']],
   'Writer::to_files',
   {tap => 'sink'}
);

$pl->(['data.txt']);
```

The output:

```
---------------------------------------------------------------
Hi Flavio! Happy birthday, now you are 44 years old!
Would you like a salad?
_______________________________________________________________
---------------------------------------------------------------
Hi FooBar! Happy birthday, now you are 29 years old!
Would you like a banana?
_______________________________________________________________
---------------------------------------------------------------
Hi What Ever! Happy birthday, now you are 52 years old!
Would you like a kiwi?
_______________________________________________________________
```

## Input Format Changes? No problem!

### A Simple CSV-like Input

Your input data changes, and it's some columns separated by semicolons in
a fixed order? I mean, like this:

```
Flavio;44;salad
FooBar;29;banana
What Ever;52;kiwi
```

No problem, just change the way you parse your input data, and leave the
rest untouched:

```perl
my $pl = pipeline(
   'Source::iterate_files',
   'Reader::by_line',

   # Only the parser changes
   ['Parser::by_format', 'name;age;food'],

   ['Renderer::with_template_perlish', ['template.tp']],
   'Writer::to_files',
   {tap => 'sink'}
);
```

### Key/Value Pairs Again

OK, you switch back to key/value pairs, but think that it's better to put
each in its own line this time? I mean, like this:

```
name:Flavio
age:44
food:salad

age:29
name:FooBar
food:banana

food:kiwi
name:What Ever
age:52
```

No problem again, you just have to read *by paragraph* instead of by
lines, and revert back to parsing *something hashy*:

```perl
my $pl = pipeline(
   'Source::iterate_files',

   # Read records by the paragraph, not by the line. Parse as hashes
   # as before, only with different separators
   'Reader::by_paragraph',
   ['Parser::hashy', chunks_separator => "\n",
    key_value_separator => ":"],

   ['Renderer::with_template_perlish', ['template.tp']],
   'Writer::to_files',
   {tap => 'sink'}
);
```

### New Change - HTTP Rules!

OK, we're almost fine but you fall in love with the HTTP specification,
and what we have here does not do automatic handling of case, removal of
leading/trailing whitespaces and continuation lines. In simple terms, it
is not capable of properly handling the following input:

```
Name:    Flavio  ␤
Age:     44  ␤
Food:    salad  ␤
␤
AGE  : 29␤
name : FooBar␤
FOOD : banana   ␤
␤
food: kiwi␤
name: What␤
 Ever␤
Age: 52   ␤
```

So... why don't you roll your own parsing step then? It's easy, and you
don't have to change anything else in your pipeline:

```perl
my $pl = pipeline(
   'Source::iterate_files',

   # Still read records by the paragraph, but parse with own tube
   'Reader::by_paragraph',

   # Custom parser, receive inputs in "raw", return output in
   # "structured" so that previous and following tubes feel at home
   sub {
      my $record = shift;
      $record->{structured} = \my %value_for;
      (my $text = $record->{raw}) =~ s{\n\s+}{ }gmxs; # continuations
      for my $line (split /\n/, $text) {
         my ($key, $value) = split /\s*:\s*/, $line, 2; # split
         s{\A\s+|\s+\z}{}gmxs for $key, $value;         # trim k/v
         $value_for{$key} = $value;
      }
      return $record;
   },

   ['Renderer::with_template_perlish', ['template.tp']],
   'Writer::to_files',
   {tap => 'sink'}
);
```

## Intrigued?

There's more than just reading/parsing flexibility, as you get to
control each step, reusing what you can and adapting when you must.
Interested? Take a look at [the manual](manual), at [some
examples](examples) or at [tubergen](tubergen), a program that will get
you up to speed in no time!
