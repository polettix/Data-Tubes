---
title: 'Data::Tubes'
layout: page
author: polettix
tagline: 'The Missing Manual'
---

# Data::Tubes - The Missing Manual

[Data::Tubes](https://metacpan.org/pod/Data::Tubes) helps you manage transformations steps on a stream of
data that can be though as a sequence of _records_. It does it by
passing _records_ through _tubes_, usually a sequence of them.

This manual is a bit long... here's a table of contents for guiding you:

* Point at which the TOC is attached
{:toc}


## A Few Definitions

A _record_ can be whatever scalar you can think of. I might even be
`undef`. What's in a record, and what it does mean, is completely up to
you --and, of course, to the tube that is going to manage that record.

A _record_ might even evolve through the pipeline to become something
different, e.g. multiple records. In other words, some tubes might take
an input record of some nature, and emit output record(s) of a
completely different one. Again, it's up to the tube to decide this,
which means that, eventually, it's up to you.

So, a _tube_ is a transformation function, that turns one single
_input record_ into zero, one or more _output records_, according to
the model drawn below:

               \________/
                           --| nothing
     input  --\            --> one output record
     record --/            ==> some output records (array reference)
                _________  ==> some output records (iterator)
               /         \

In more formal terms, a _tube_ is a sub reference that:

- is able to take exactly one input argument (the _input record_),
although it can receive more or less in different contexts (i.e. when
called outside of the _tube_ definition);
- at each call in _list context_, returns one of the following (every
call is a story apart, of course):
    - _nothing_ (i.e. the empty list);

    - _exactly one scalar_, representing the _output record_;

    - the string `records` followed by an _array reference_, containing
      the sequence of _output records_;

    - the string _iterator_ followed by a _sub reference_, from where you
      can draw the _output records_.

The iterator has some additional constraints:

- when called in _list context_, returns the empty list or exactly one
scalar value;
- if it returns the empty list, it means that the iterator is exhausted
and it cannot emit any more _output records_;
- otherwise, it returns exactly one scalar, representing the _next output
record_.

So far so good with definitions, but let's recap: a _record_ is a
scalar, a _tube_ is a sub reference.

## Typical Use Case

The typical use case for transforming data (e.g. in some ETL) can be
summarized as follows, at least for me:

- _manage sources_
- _read_ input data, chunking them into raw textual/binary
representations of a single record;
- _parse_ read data, hoping it adheres to some structure, and generating
a structured version of it (typically a Perl hash or array reference,
holding the parsed data);
- _render_ the output based on the input record, most of the time filling
a template with values read from the input;
- _write_ the rendered text/binary data to some output channel.

All the above operations have to be performed in sequence, and repeated
until the sources cannot emit any more data to be read.

[Data::Tubes](https://metacpan.org/pod/Data::Tubes) helps you with managing the sequencing, make sure that
you exhaust your sources, and also provides tools for addressing each
step.

Note that your steps might be different. For example, you might want to
introduce an intermediate step between the parsing and the rendering, to
perform some data validation. You might want to perform a different
rendering based on what has been parsed, or validated. You might want to
select a different output channel based on what was parsed. So, although
it's a sequence, you might actually think your pipeline as possibly
dividing into multiple alternatives at some steps, using data that come
from any of the previous steps. [Data::Tubes](https://metacpan.org/pod/Data::Tubes) tools help you with this
too!

In the following sections, we will gradually introduce the different
tools available from [Data::Tubes](https://metacpan.org/pod/Data::Tubes) and show you how they can help you
address the use case above, or the variant you might have.

## What You Need 99% Of The Times

In most of the cases, you will only need to use function `pipeline`
from the main module [Data::Tubes](https://metacpan.org/pod/Data::Tubes). It allows you to define a sequence
of tubes, or things that can be turned into tubes, with minimal hassle.

To show you how to use it, we will replicate the behaviour of the
following simple program:

    my @names = qw< Foo Bar Baz >;
    for my $name (@names) {
       print "Hey, $name!\n";
    }

We can re-implement it with [Data::Tubes](https://metacpan.org/pod/Data::Tubes) using much, much more code!
Here's some way to do it:

    use Data::Tubes qw< pipeline >;
    my @names = qw< Foo Bar Baz >;
    pipeline(
       sub { return records => $_[0] }, # will iterate over items
       sub { return "Hey, $_[0]!\n"  }, # returns the string
       sub { print $_[0]; return },     # prints it, returns nothing
       { tap => 'sink' },               # makes sure the input is drained
    )->(\@names);

Does not seem to be very exciting, huh? Whatever, it allows us to get
our feet wet with `pipeline`:

- it returns a sub reference that behaves like a tube itself. The `tap`
indication in the final options hash reference says that the output
should be thrown in the `sink`, so this tube will always return
nothing, but it's ok;
- it makes sure to get the output from a tube, and feed the following tube
accordingly. In particular, if a tube returns multiple records (e.g. the
first tube does this, as it returns `records` and a reference to an
array), it takes care to iterate over all of them and feed them to the
following tube one by one;
- it does not make any assumption as to the nature of the _record_ at
each step
- thanks to the specific setting for `tap`, it takes care to exhaust all
inputs and possible intermediate records that are generated.

Of course, we might have decided that the rendering step was not needed
in our case, so we might have done something like this:

    use Data::Tubes qw< pipeline >;
    my @names = qw< Foo Bar Baz >;
    pipeline(
       sub { return records => $_[0] }, # will iterate over items
       sub { print "Hey, $_[0]!\n"   },
       { tap => 'sink' },               # makes sure the input is drained
    )->(\@names);

It really depends on what you want to do. In general terms, it's still
useful to think the pipeline in terms of the ["Typical Use Case"](#typical-use-case),
because the toolset provided by [Data::Tubes](https://metacpan.org/pod/Data::Tubes)' plugins usually provide
you only one of those steps but, again, it's up to you.

## Managing Sources

The initial tube of a sequence is, arguably, your source. From a
phylosophical point of view, you can view it as a transformation of the
inputs you will eventually provide (as in the example we saw in the last
section), or as a self-contained tube that is able to conjure things out
of nothing. You decide.

If you happen to take your inputs from files, the toolbox provides you
with a few tools inside [Data::Tubes::Plugin::Source](https://metacpan.org/pod/Data::Tubes::Plugin::Source). One, in
particular, will be your friend most of the times: `iterate_files`.

This function is a _factory_, in the sense that you give it some
arguments and it returns you a tube-compliant sub reference. All it does
is to transform an input array reference containing file names into a
data structure that contains a filehandle suitable for reading from
those files.

Suppose you have your names in two files instead of an array:

    $ cat mydata-01.txt
    Foo
    Bar
    $ cat mydata-02.txt
    Baz

you can do like this:

    use Data::Tubes qw< pipeline >;
    pipeline(
       '+Source::iterate_files',
       sub {
          my $fh = $_[0]->{source}{fh};
          chomp(my @names = <$fh>);
          return records => \@names;
       }                                # read records from one source
       sub { return "Hey, $_[0]!\n"  }, # returns the string
       sub { print $_[0]; return },     # prints it, returns nothing
       { tap => 'sink' },               # makes sure the input is drained
    )->([qw< mydata-01.txt mydata-02.txt >]);

In other terms, you have substituted the input gathering process with
different tubes, while keeping the rest of the pipeline as it was
before.

We can notice one interesting thing about `pipeline`: in addition to
_real_ tubes, i.e. sub references, it can accept simple strings as
well, that it will take care to automatically transform into tubes. In
this case, it first turns `+Source::iterate_files` into
`Data::Tubes::Plugin::Source::iterate_files`, then loads the function
`iterate_files` from the relevant module and used it as a factory to
generate the real tube. We will see later how we can pass additional
parameters to this factory functions.

There are also a few things that are interesting about `iterate_files`
(you're encouraged to read the docs in [Data::Tubes::Plugin::Source](https://metacpan.org/pod/Data::Tubes::Plugin::Source),
of course):

- it gets as input array references, containing lists of file names. The
list might be empty or contain any number of files, of course
- it takes care to open them for you, returning a series of records with
details about the file;
- each output record is a hash reference, containing a sub-hash associated
to the key `source`, that holds data about the file (like the filename,
a conventional name for the channel, and of course the filehandle in key
`fh`).

## What Is A Record, Toolkit Style

The representation of the output record from `iterate_files` explained
in the previous section does not come out of the blue: the whole plugins
toolkit, with very few exceptions, works under the assumption that a
record, in each step, is a hash reference where each tube takes and adds
data. In particular, The different components in the toolkit make the
following assumptions:

- [Data::Tubes::Plugin::Source](https://metacpan.org/pod/Data::Tubes::Plugin::Source) takes input from an array reference, and
emits hash references with a sub-hash pointed by key `source`;
- [Data::Tubes::Plugin::Reader](https://metacpan.org/pod/Data::Tubes::Plugin::Reader) expect to receive a hash reference with
key `source`, from where they take the `fh` field, and populate field
`raw` with whatever they read;
- [Data::Tubes::Plugin::Parser](https://metacpan.org/pod/Data::Tubes::Plugin::Parser) receive a hash reference with key `raw`,
and populate key `structured`;
- [Data::Tubes::Plugin::Renderer](https://metacpan.org/pod/Data::Tubes::Plugin::Renderer) receive a hash reference with key
`structured`, and populate key `rendered`;
- [Data::Tubes::Plugin::Writer](https://metacpan.org/pod/Data::Tubes::Plugin::Writer) receive a hash reference with key
`rendered`, and do not populate anything more (although they pass the
record along as output).

So, basically, whatever is emitted by one plugin type is good as input
for the _following_ plugin type:

    Source       Reader      Parser           Renderer       Writer
      |           ^  |        ^  |              ^  |            ^
      |           |  |        |  |              |  |            |
      +-> source -+  +-> raw -+  +- structured -+  +- rendered -+

with the notable exception that each step actually receives _all_ the
sub-fields populated by the previous tubes, which can be used to
customize the behaviour depending on your actual use case.

This sequence can also be useful for you to know if you want to insert
some behaviour in between. We will see some examples later.

## Reading

Remember the last example from ["Managing Sources"](#managing-sources)? Here's a refresher:

    use Data::Tubes qw< pipeline >;
    pipeline(
       '+Source::iterate_files',
       sub {
          my $fh = $_[0]->{source}{fh};
          chomp(my @names = <$fh>);
          return records => \@names;
       }                                # read records from one source
       sub { return "Hey, $_[0]!\n"  }, # returns the string
       sub { print $_[0]; return },     # prints it, returns nothing
       { tap => 'sink' },               # makes sure the input is drained
    )->([qw< mydata-01.txt mydata-02.txt >]);

It turns out that you actually don't need to do the reading of the file
line by line yourself, because there's a plugin to do that. The only
thing that we have to consider is that the read line will be put in the
`raw` field of a hash-based record:

    use Data::Tubes qw< pipeline >;
    pipeline(
       'Source::iterate_files',
       'Reader::by_line',
       sub { return "Hey, $_[0]->{raw}!\n"  }, # returns the string
       sub { print $_[0]; return },     # prints it, returns nothing
       { tap => 'sink' },               # makes sure the input is drained
    )->([qw< mydata-01.txt mydata-02.txt >]);

Your eagle eye will surely have noticed that we got rid of the initial
plus sign before the name of the plugin. If your plugin lives directly
under the `Data::Tubes::Plugin` namespace, this is fine (although, if
you go deeper, like `Data::Tubes::Plugin::Foo::Bar::Baz`, you will need
to put the plus sign to get rid of the initial part until `Plugin`
included).

A plugin to read by line might seem overkill, but it already started
sparing us a few lines of code, and I guess there are plenty of
occasions where your input records are line-based. You're invited to
take a look at [Data::Tubes::Plugin::Reader](https://metacpan.org/pod/Data::Tubes::Plugin::Reader), where you might find
`by_paragraph`, that reads... by the paragraph, and other reading
functions.

## Passing Options To Plugins

All of a sudden, your greetings applications starts to choke and you
eventually figure that it depends on the encoding of the input file. In
particular, you discover that `iterate_files` defaults on opening files
as `UTF-8`, which is fine per-se, but when you print things out you get
strange messages and unfortunately your boss stops you from setting the
same encoding on STDOUT.

Don't despair! You have a few arrows available. The first one is to just
turn the input filehandle back to `:raw`, like this:

    use Data::Tubes qw< pipeline >;
    pipeline(
       'Source::iterate_files',
       sub { binmode $_[0]->{source}{fh}, ':raw'; return $_[0]; },
       'Reader::by_line',
       sub { return "Hey, $_[0]->{raw}!\n"  }, # returns the string
       sub { print $_[0]; return },     # prints it, returns nothing
       { tap => 'sink' },               # makes sure the input is drained
    )->([qw< mydata-01.txt mydata-02.txt >]);

The second one is to avoid setting the encoding in `iterate_files` in
the first place, which can be obtained by passing options to the
factory. This is obtained by substituting the simple string with an
array reference, where the first item is the same as the string (i.e. a
_locator_ for the factory function), and the following ones are
arguments for the factory itself:

    use Data::Tubes qw< pipeline >;
    pipeline(
       ['Source::iterate_files', open_file_args => {binmode => ':raw'}],
       'Reader::by_line',
       sub { return "Hey, $_[0]->{raw}!\n"  }, # returns the string
       sub { print $_[0]; return },     # prints it, returns nothing
       { tap => 'sink' },               # makes sure the input is drained
    )->([qw< mydata-01.txt mydata-02.txt >]);

## Parsing

So far, we relied upon the assumption that the whole input line is what
we are really after, and we don't need to parse it any more. Alas, this
is not the case most of the times.

If you have some complicated format, your best option is to just code a
tube to deal with it. For example, the following code would turn a
paragraph with HTTP headers into a hash of arrays:

    sub parse_HTTP_headers {
       my $headers = shift;
       $headers =~ s{\n\s+}{ }gmxs; # remove multi-lines
       my %retval;
       for my $line (split /\n/mxs, $headers) {
          my ($name, $value) = split /\s*:\s*/, $line, 2;
          s{\A\s+|\s+\z}mxs for $name, $value; # lead/trail spaces
          if (! exists $retval{$name}) {
             $retval{$name} = $value;
          }
          else {
             $retval{$name} = [$retval{$name}] # turn into array ref
                unless ref $retval{$name};     # if necessary
             push @{$retval{$name}}, $value;
          }
       }
       return \%retval;
    }

Now, suppose your input changes to a sequence of header groups, divided
into paragraphs, where you look for header `X-Name`:

    $ cat mydata-03.txt
    X-Name: Foo
    Host: example.com

    X-Name: Bar
     Barious
    Date: 1970-01-01

Adapting to this input is quite easy now:

    use Data::Tubes qw< pipeline >;
    pipeline(
       ['Source::iterate_files', open_file_args => {binmode => ':raw'}],

       'Reader::by_paragraph',                  # change how we read!
       sub { parse_HTTP_Headers($_[0]->{raw}) } # wrap parse_HTTP_headers
       sub { return "Hey, $_[0]->{'X-Name'}!\n"  }, # use new field

       sub { print $_[0]; return },     # prints it, returns nothing
       { tap => 'sink' },               # makes sure the input is drained
    )->([qw< mydata-03.txt >]);

From now on, anyway, we will stick to the convention described in
_What Is A Record, Toolkit Style_ about what's available at the
different stages, which allows us have stable inputs for tubes without
having to worry too much about what we have before (within certain
limits). Hence, here's how our example transforms:

    use Data::Tubes qw< pipeline >;
    pipeline(
       # Source management
       ['Source::iterate_files', open_file_args => {binmode => ':raw'}],

       # Reading, gets `source`, puts `raw`
       'Reader::by_paragraph',

       # Parsing, gets `raw`, puts `structured`
       sub {
          my $record = shift;
          $record->{structured} = parse_HTTP_Headers($record->{raw});
          return $record;
       }

       # Rendering, gets `structured`, puts `rendered`
       sub {
          my $record = shift;
          $record->{rendered} = 
             "Hey, $record->{structured}{'X-Name'}!\n";
          return $record;
       },

       # Printing, gets `rendered`, returns input unchanged
       sub { print $_[0]{rendered}; return $_[0]; },

       # Options, just flush the output to the sink
       { tap => 'sink' },
    )->([qw< mydata-03.txt >]);

As anticipated, [Data::Tubes::Plugin::Parser](https://metacpan.org/pod/Data::Tubes::Plugin::Parser) contains some pre-canned
factories for generating common parsers, mostly geared to line-oriented
inputs (which can be quite common, anyway). So, if your input is as
simple as a sequence of fields separated by a character, without
anything fancy like quoting or escaping, you can simply rely on a
_format_. For example, suppose you have the following data, with a name
(that we will assume does not contain a semicolon inside), the nickname
(ditto) and the age:

    $ cat mydata-04.txt
    Foo;foorious;32
    Bar;barious;19
    Baz;bazzecolas;44

You might describe each line as being `name;nick;age`, and this is
exactly what's needed to use `by_format`:

    use Data::Tubes qw< pipeline >;
    pipeline(
       # Source management
       ['Source::iterate_files', open_file_args => {binmode => ':raw'}],

       # Reading, gets `source`, puts `raw`
       'Reader::by_line',

       # Parsing, gets `raw`, puts `structured`
       ['Parser::by_format', format => 'name;nick;age'],

       # Rendering, gets `structured`, puts `rendered`
       sub {
          my $record = shift;
          my $v = $record->{structured};
          $record->{rendered} = 
             "Hey, $v->{name} (alias $v->{nick}), it's $v->{age}!\n";
          return $record;
       },

       # Printing, gets `rendered`, returns input unchanged
       sub { print $_[0]{rendered}; return $_[0]; },

       # Options, just flush the output to the sink
       { tap => 'sink' },
    )->([qw< mydata-04.txt >]);

Actually, any sequence of non-word characters (Perl-wise) is considered
a separator in the format, and any sequence of word characters is
considered the name of a field.

Another useful pre-canned parser in the toolkit is `hashy`, that allows
you to handle something more complicated like sequences of key-value
pairs. The assumption here is that there are two separators: one for
separating key-value pairs, one for separating the key from the value.
Here's another example, assuming that the pipe character separates
pairs, and the equal sign separates the key from the value:

    $ cat mydata-05.txt
    name=Foo Foorious|nick=foorious|age=32
    name=Bar Barious|age=19|nick=barious
    age=44|nick=bazzecolas|name=Baz Bazzecolas

As you see, explicit naming of fields allows you to put them in any
order inside the input:

    use Data::Tubes qw< pipeline >;
    pipeline(
       ['Source::iterate_files', open_file_args => {binmode => ':raw'}],
       'Reader::by_line',

       # Parsing, gets `raw`, puts `structured`
       ['Parser::hashy', chunks_separator => '|',
          key_value_separator = '='],

       # Rendering, gets `structured`, puts `rendered`
       sub {
          my $record = shift;
          my $v = $record->{structured};
          $record->{rendered} = 
             "Hey, $v->{name} (alias $v->{nick}), it's $v->{age}!\n";
          return $record;
       },

       # Printing, gets `rendered`, returns input unchanged
       sub { print $_[0]{rendered}; return $_[0]; },

       # Options, just flush the output to the sink
       { tap => 'sink' },
    )->([qw< mydata-05.txt >]);

`hashy` also allows setting a _default key_, in case none is found for
a pair, so that you can have something like this if your lines are
_indexed_ by nick:

    $ cat mydata-06.txt
    foorious|name=Foo Foorious|age=32
    barious|name=Bar Barious|age=19
    bazzecolas|age=44|name=Baz Bazzecolas

Ordering in this case is purely incidental, again the un-keyed element
can occur anywhere. The transformation is easy:

    use Data::Tubes qw< pipeline >;
    pipeline(
       ['Source::iterate_files', open_file_args => {binmode => ':raw'}],
       'Reader::by_paragraph',

       # Parsing, gets `raw`, puts `structured`
       ['Parser::hashy', default_key => 'nick',
          chunks_separator => '|', key_value_separator = '='],

       # Rendering, gets `structured`, puts `rendered`
       sub {
          my $record = shift;
          my $v = $record->{structured};
          $record->{rendered} = 
             "Hey, $v->{name} (alias $v->{nick}), it's $v->{age}!\n";
          return $record;
       },

       # Printing, gets `rendered`, returns input unchanged
       sub { print $_[0]{rendered}; return $_[0]; },

       # Options, just flush the output to the sink
       { tap => 'sink' },
    )->([qw< mydata-06.txt >]);

There are more to discover, take a look at
[Data::Tubes::Plugin::Parser](https://metacpan.org/pod/Data::Tubes::Plugin::Parser).

## Rendering

If you have to render a very simple string like the salutation we saw so
far, the simple system we used so far is quite effective. If your output
gets any more complicated, chances are you can benefit from using a
template. The plugin [Data::Tubes::Plugin::Renderer](https://metacpan.org/pod/Data::Tubes::Plugin::Renderer) provides you a
factory to use templates built for [Template::Perlish](https://metacpan.org/pod/Template::Perlish), let's see how.

    use Data::Tubes qw< pipeline >;
    pipeline(
       ['Source::iterate_files', open_file_args => {binmode => ':raw'}],
       'Reader::by_line',
       ['Parser::by_format', format => 'name;nick;age'],

       # Rendering, gets `structured`, puts `rendered`
       ['Renderer::with_template_perlish', format => <<'END' ],
    Hey [% name %]!

    ... or should I call you [% nick %]?

    It's your birthday, you're [% age %] now!
    END

       # Printing, gets `rendered`, returns input unchanged
       sub { print $_[0]{rendered}; return $_[0]; },

       # Options, just flush the output to the sink
       { tap => 'sink' },
    )->([qw< mydata-04.txt >]);

As long as you only have _simple_ variables, [Template::Perlish](https://metacpan.org/pod/Template::Perlish)
behaves much like the famous [Template](https://metacpan.org/pod/Template) toolkit. Anything more
complicated leads you to using Perl, anyway.

The same sequence can of course be used to render the input data in some
other format, e.g. as YAML as in the following example (we're ignoring
the need to do any escaping, of course):

    use Data::Tubes qw< pipeline >;
    pipeline(
       ['Source::iterate_files', open_file_args => {binmode => ':raw'}],
       'Reader::by_line',
       ['Parser::by_format', format => 'name;nick;age'],

       # Rendering, gets `structured`, puts `rendered`
       ['Renderer::with_template_perlish', format => <<'END' ],
    -
       name: [% name %]
       nick: [% nick %]
       age: [% age %]
    END

       # Printing, gets `rendered`, returns input unchanged
       sub { print $_[0]{rendered}; return $_[0]; },

       # Options, just flush the output to the sink
       { tap => 'sink' },
    )->([qw< mydata-04.txt >]);

We're putting the object element inside an array, so that the sequence
will print out smoothly as an overall YAML file.

## Writing

The last step in our typical pipeline is writing out stuff. So far, we
just printed things out on STDOUT, but by no means we're limited to
this! Let's take a look at [Data::Tubes::Plugin::Writer](https://metacpan.org/pod/Data::Tubes::Plugin::Writer).

The first tool that can help us is `write_to_files`, that allows us to
transform our pipeline like this (without changing the behaviour):

    use Data::Tubes qw< pipeline >;
    pipeline(
       ['Source::iterate_files', open_file_args => {binmode => ':raw'}],
       'Reader::by_line',
       ['Parser::by_format', format => 'name;nick;age'],
       ['Renderer::with_template_perlish', format => <<'END' ],
    -
       name: [% name %]
       nick: [% nick %]
       age: [% age %]
    END

       # Printing, gets `rendered`, returns input unchanged
       ['Writer::to_files', filename => \*STDOUT],

       # Options, just flush the output to the sink
       { tap => 'sink' },
    )->([qw< mydata-04.txt >]);

From here, it's easy to deduce that you can pass other things as
`filename`, for example... a filename!

### Framing records

The writer tools rely upon [Data::Tubes::Util::Output](https://metacpan.org/pod/Data::Tubes::Util::Output), that is a smart
wrapper that allows you to handle multiple cases. For example, suppose
that instead of YAML you want to output JSON; you might start with this:

    use Data::Tubes qw< pipeline >;
    pipeline(
       ['Source::iterate_files', open_file_args => {binmode => ':raw'}],
       'Reader::by_line',
       ['Parser::by_format', format => 'name;nick;age'],
       ['Renderer::with_template_perlish', format => <<'END' ],
    {"name":"[% name %];"nick":"[% nick %]";"age":[% age %]}
    END

       # Printing, gets `rendered`, returns input unchanged
       ['Writer::to_files', filename => \*STDOUT],

       # Options, just flush the output to the sink
       { tap => 'sink' },
    )->([qw< mydata-04.txt >]);

There's a problem though: for more than one input record, the output is
not valid JSON:

    {"name":"Foo","nick":"foorious","age":32}
    {"name":"Bar","nick":"barious","age":19}
    {"name":"Baz","nick":"bazzecolas","age":44}

We should put this in an array, and we should separate the objects with
a comma. The first thing might be naively solved like this:

    use Data::Tubes qw< pipeline >;

    # DO NOT USE THIS SOLUTION!
    print "[\n";

    pipeline(
       ['Source::iterate_files', open_file_args => {binmode => ':raw'}],
       'Reader::by_line',
       ['Parser::by_format', format => 'name;nick;age'],
       ['Renderer::with_template_perlish', format => <<'END' ],
    {"name":"[% name %];"nick":"[% nick %]";"age":[% age %]}
    END

       # Printing, gets `rendered`, returns input unchanged
       ['Writer::to_files', filename => \*STDOUT],

       # Options, just flush the output to the sink
       { tap => 'sink' },
    )->([qw< mydata-04.txt >]);

    # DO NOT USE THIS SOLUTION!
    print "]\n"

This has two problems:

- first of all, it does not allow you to change the output channel. What
if you are writing to a file instead?
- you still have to figure out how to print out the separator comma!

Unfortunately, JSON is quite picky in the presence of separator commas,
in that it does not allow you to have a trailing one, so the following
would be incorrect:

    [
    {"name":"Foo","nick":"foorious","age":32},
    {"name":"Bar","nick":"barious","age":19},
    {"name":"Baz","nick":"bazzecolas","age":44},
    ]

because the last comma would be out of place.

Fortunately, `to_files` can help you:

    use Data::Tubes qw< pipeline >;
    pipeline(
       ['Source::iterate_files', open_file_args => {binmode => ':raw'}],
       'Reader::by_line',
       ['Parser::by_format', format => 'name;nick;age'],
       ['Renderer::with_template_perlish', format => <<'END' ],
    {"name":"[% name %];"nick":"[% nick %]";"age":[% age %]}
    END

       # Printing, gets `rendered`, returns input unchanged
       ['Writer::to_files', filename => \*STDOUT,
          header => "[\n", footer => "]\n", interlude => ','
       ],

       # Options, just flush the output to the sink
       { tap => 'sink' },
    )->([qw< mydata-04.txt >]);

The above code produces:

    [
    {"name":"Foo","nick":"foorious","age":32}
    ,{"name":"Bar","nick":"barious","age":19}
    ,{"name":"Baz","nick":"bazzecolas","age":44}
    ]

that is probably not very good-looking, but at least correct and also
working correctly whatever the output filename you set. You can change
things to make it better looking, though; just get rid of the newline in
the template, add it after the comma and put some indentation:

    use Data::Tubes qw< pipeline >;
    pipeline(
       ['Source::iterate_files', open_file_args => {binmode => ':raw'}],
       'Reader::by_line',
       ['Parser::by_format', format => 'name;nick;age'],
       ['Renderer::with_template_perlish', format =>
          '  {"name":"[% name %];"nick":"[% nick %]";"age":[% age %]}'],

       # Printing, gets `rendered`, returns input unchanged
       ['Writer::to_files', filename => \*STDOUT,
          header => "[\n", footer => "\n]\n", interlude => ",\n"
       ],

       # Options, just flush the output to the sink
       { tap => 'sink' },
    )->([qw< mydata-04.txt >]);

This now prints:

    [
      {"name":"Foo","nick":"foorious","age":32},
      {"name":"Bar","nick":"barious","age":19},
      {"name":"Baz","nick":"bazzecolas","age":44}
    ]

which you might like more.

### Segmenting the output

If you're handling _a lot_ of input records, you might want to segment
the output in order to distribute the output records into multiple
files, instead of having only one single file. It turns out that
`to_files` gets you covered also in this case!

The basic thing that you can do is to set a _policy_ object, where you
can set two keys: `records_threshold` and `characters_threshold`. They
set a threshold that will close the output channel when overcome, and
open a new one. We will assume that we're writing to files here:

    use Data::Tubes qw< pipeline >;
    pipeline(
       ['Source::iterate_files', open_file_args => {binmode => ':raw'}],
       'Reader::by_line',
       ['Parser::by_format', format => 'name;nick;age'],
       ['Renderer::with_template_perlish', format =>
          '  {"name":"[% name %];"nick":"[% nick %]";"age":[% age %]}'],

       # Printing, gets `rendered`, returns input unchanged
       ['Writer::to_files', filename => 'output-01.json',
          header => "[\n", footer => "\n]\n", interlude => ",\n",
          policy => {records_threshold => 2},
       ],

       # Options, just flush the output to the sink
       { tap => 'sink' },
    )->([qw< mydata-04.txt >]);

The example above produces two output files:

    $ cat output-01.json
    [
      {"name":"Foo","nick":"foorious","age":32},
      {"name":"Bar","nick":"barious","age":19}
    ]
    $ cat output-01.json_1
    [
      {"name":"Baz","nick":"bazzecolas","age":44}
    ]

Again, valid JSON files with the correct number of (maximum) records.
You might have some issues with the file names, though, especially if
you rely on the file extension to do... anything.

`to_files` allows you to set a filename template, using `sprintf`-like
sequences using `%n`, like this:

    use Data::Tubes qw< pipeline >;
    pipeline(
       ['Source::iterate_files', open_file_args => {binmode => ':raw'}],
       'Reader::by_line',
       ['Parser::by_format', format => 'name;nick;age'],
       ['Renderer::with_template_perlish', format =>
          '  {"name":"[% name %];"nick":"[% nick %]";"age":[% age %]}'],

       # Printing, gets `rendered`, returns input unchanged
       ['Writer::to_files', filename => 'output-02-%03n.json',
          header => "[\n", footer => "\n]\n", interlude => ",\n",
          policy => {records_threshold => 2},
       ],

       # Options, just flush the output to the sink
       { tap => 'sink' },
    )->([qw< mydata-04.txt >]);

The example above produces two output files:

    $ cat output-02-000.json
    [
      {"name":"Foo","nick":"foorious","age":32},
      {"name":"Bar","nick":"barious","age":19}
    ]
    $ cat output-02-001.json
    [
      {"name":"Baz","nick":"bazzecolas","age":44}
    ]

This should make you happy, at least!

### Output encoding

Last thing you need to know about `to_files` is that you can set the
encoding too, just set a `CORE::binmode` compatible string using the
`binmode` argument, that is set to `:encoding(UTF-8)` by default.

    use Data::Tubes qw< pipeline >;
    pipeline(
       ['Source::iterate_files', open_file_args => {binmode => ':raw'}],
       'Reader::by_line',
       ['Parser::by_format', format => 'name;nick;age'],
       ['Renderer::with_template_perlish', format =>
          '  {"name":"[% name %];"nick":"[% nick %]";"age":[% age %]}'],

       # Printing, gets `rendered`, returns input unchanged
       ['Writer::to_files', filename => 'output-02-%03n.json',
          header => "[\n", footer => "\n]\n", interlude => ",\n",
          policy => {records_threshold => 2},
          binmode => ':raw',
       ],

       # Options, just flush the output to the sink
       { tap => 'sink' },
    )->([qw< mydata-04.txt >]);

Now, you have full control over your input. Or have you?

## Writing, Reloaded

In the previous section about ["Writing"](#writing) we saw that there's a very
flexible tool `to_files`. Is it sufficient to get you covered in all
cases? Arguably not.

Suppose that you want to divide your outputs in two groups, one with
people with nicknames starting with letter `a` to `m`, another with
the rest. How do you do this?

### Dispatching manually

One interesting thing about the toolkit is that you can use its function
outside of `pipeline`, if you need to. The `summon` function helps you
import the right function with minimal hassle:

    use Data::Tubes qw< pipeline summon >;
    my $writer_factory = summon('Writer::to_files');

Now, for example, you can do like this:

    use Data::Tubes qw< pipeline summon >;

    # pre-define two output channels, for lower and other initial chars
    summon('Writer::to_files');
    my $lower = to_files(
       filename => 'output-lower-%02d.json',
       header => "[\n", footer => "\n]\n", interlude => ",\n",
       policy => {records_threshold => 2},
       binmode => ':raw',
    );
    my $other = to_files(
       filename => 'output-other-%02d.json',
       header => "[\n", footer => "\n]\n", interlude => ",\n",
       policy => {records_threshold => 2},
       binmode => ':raw',
    );

    pipeline(
       ['Source::iterate_files', open_file_args => {binmode => ':raw'}],
       'Reader::by_line',
       ['Parser::by_format', format => 'name;nick;age'],
       ['Renderer::with_template_perlish', format =>
          '  {"name":"[% name %];"nick":"[% nick %]";"age":[% age %]}'],

       # Printing, gets `rendered`, returns input unchanged
       sub { # wrapper!
          my $record = shift;
          my $first_char = substr $record->{structured}{nick}, 0, 1;
          return $lower->($record) if $first_char =~ m{[a-m]}mxs;
          return $other->($record);
       },

       # Options, just flush the output to the sink
       { tap => 'sink' },
    )->([qw< mydata-04.txt >]);

If you have some complicated business logic... you can always use this
technique! But there's more... read on.

### Dispatching, the movie

Considering that dispatching can be quite common, you can guess that
there's something in the toolkit to get you covered. You guessed right!

[Data::Tubes::Plugin::Writer](https://metacpan.org/pod/Data::Tubes::Plugin::Writer) provides you `dispatch_to_files`, that
helps you streamline what we saw in the previous section. Here's how:

    use Data::Tubes qw< pipeline >;
    pipeline(
       ['Source::iterate_files', open_file_args => {binmode => ':raw'}],
       'Reader::by_line',
       ['Parser::by_format', format => 'name;nick;age'],
       ['Renderer::with_template_perlish', format =>
          '  {"name":"[% name %];"nick":"[% nick %]";"age":[% age %]}'],

       # Printing, gets `rendered`, returns input unchanged
       ['Writer::dispatch_to_files',
          header => "[\n", footer => "\n]\n", interlude => ",\n",
          policy => {records_threshold => 2},
          filename_template => 'output-[% key %]-%03n.json',
          selector => sub {
             my $record = shift;
             my $first_char = substr $record->{structured}{nick}, 0, 1;
             return 'lower' if $first_char =~ m{[a-m]}mxs;
             return 'other';
          },
       ],

       # Options, just flush the output to the sink
       { tap => 'sink' },
    )->([qw< mydata-04.txt >]);

Most parameters are the same as `to_files`, so we already know about
them. We have two new ones, though: `filename_template` and
`selector`.

The latter (`selector`) is a sub reference that receives the record as
input, and is supposed to provide a _key_ back. Whenever this key is
the same, the output channel chosen by the dispatcher will be the same.
In this case, we are outputting two strings, namely `lower` and
`other`.

The `filename_template` is an extension on parameter `filename`, that
allows you to put additional things in the `filename` that is
eventually passed to `to_files`. As you might have guessed already,
it's a [Template::Perlish](https://metacpan.org/pod/Template::Perlish)-compatible template, where you can expand
the variable `key`. So:

- if the `selector` returns `lower`, the `filename_template` is
expanded into `output-lower-%03n.json`;
- if the `selector` returns `other`, the `filename_template` is
expanded into `output-other-%03n.json`;

Nifty, huh?

## Dispatching, Reloaded

In ["Dispatching, the movie"](#dispatching-the-movie) we saw that you can dispatch to the right
output channel depending on what's inside each single record. The
dispatching technique can be applied to other stages, though, if you are
brave enough to look at `dispatch` in [Data::Tubes::Plugin::Plumbing](https://metacpan.org/pod/Data::Tubes::Plugin::Plumbing).

### General dispatching

For example, suppose that you want to divide your input records stream
into two different flows, one for records that are _good_, one for the
_bad_ (e.g. records that do not parse correctly, or do not adhere to
some additional validation rules).

In the example below, we will assume that nicknames starting with any
letter are good, and bad otherwise. We still want to do some rendering
for the bad ones, though, because we want to write out an error file.

    use Data::Tubes qw< pipeline summon >;

    summon('Renderer::with_template_perlish');
    my $render_good = with_template_perlish(format =>
       '  {"name":"[% name %];"nick":"[% nick %]";"age":[% age %]}'],);
    # the "bad" renderer just complains about the nickname
    my $render_bad = with_template_perlish(format =>
       '  {"nick":"[% nick %]";"error":"invalid"}'],);

    pipeline(
       ['Source::iterate_files', open_file_args => {binmode => ':raw'}],
       'Reader::by_line',
       ['Parser::by_format', format => 'name;nick;age'],

       # let's put an intermediate step to "classify" the record
       sub {
          my $record;
          my $first_char = substr $record->{structured}{nick}, 0, 1;
          $record->{class} = ($first_char =~ m{[a-m]}mxs) ? 'lower'
                            :($first_char =~ m{[a-z]}imxs) ? 'other'
                            :                                'error';
          return $record;
       }

       # Rendering is wrapped by dispatch here
       ['Plumbing::dispatch', key => 'class',
          factory => sub {
             my $key = shift;
             return $render_bad if $key eq 'error';
             return $render_good;
          }
       ]

       # Printing, gets `rendered`, returns input unchanged
       ['Writer::dispatch_to_files',
          header => "[\n", footer => "\n]\n", interlude => ",\n",
          policy => {records_threshold => 2},
          filename_template => 'output-[% key %]-%03n.json',
          key => 'class',
       ],

       # Options, just flush the output to the sink
       { tap => 'sink' },
    )->([qw< mydata-04.txt >]);

The `dispatcher` is based on two steps: one is the _selection_, the
other one is the _generation_.

As we saw previously, the _selection_ process is about getting a key
that allows the dispatcher to figure out what channel to use. In
["Dispatching, the movie"](#dispatching-the-movie) we saw that we can put a `selector` key in
the arguments, but if you already have your key in the record you can
just set a `key` argument. In this example, we're doing this
classification immediately after the parse phase, so from that point on
we have a `class` key inside the record, that we can use (and we do,
both in `dispatch` and in `dispatch_to_files`).

In case the dispatcher does not (yet) know which tube is associated to a
given string returned by the _selector_, it's time for some
_generation_. `dispatch_to_files` already knows how to generate files
(although you can override this), and is fine with `filename_template`;
on the other hand, the generic `dispatch` needs to know something more,
which is why we're using `factory` here.

The `factory` in a dispatcher allows you to receive the key returned by
the selector (and also the whole record, should you need it) and return
a _tube_ back. Guess what? That tube will be associated to that key
from now on!

### Pre-loading the cache

If you already have your downstream tubes available (as in our case),
you can pre-load the cache and avoid coding the factory completely:

    use Data::Tubes qw< pipeline summon >;

    summon('Renderer::with_template_perlish');
    my $render_good = with_template_perlish(format =>
       '  {"name":"[% name %];"nick":"[% nick %]";"age":[% age %]}'],);
    # the "bad" renderer just complains about the nickname
    my $render_bad = with_template_perlish(format =>
       '  {"nick":"[% nick %]";"error":"invalid"}'],);

    pipeline(
       ['Source::iterate_files', open_file_args => {binmode => ':raw'}],
       'Reader::by_line',
       ['Parser::by_format', format => 'name;nick;age'],

       # let's put an intermediate step to "classify" the record
       sub {
          my $record;
          my $first_char = substr $record->{structured}{nick}, 0, 1;
          $record->{class} = ($first_char =~ m{[a-m]}mxs) ? 'lower'
                            :($first_char =~ m{[a-z]}imxs) ? 'other'
                            :                                'error';
          return $record;
       }

       # Rendering is wrapped by dispatch here
       ['Plumbing::dispatch', key => 'class',
          handlers => {
             lower => $render_good,
             other => $render_good,
             error => $render_bad,
          },
       ]

       # Printing, gets `rendered`, returns input unchanged
       ['Writer::dispatch_to_files',
          header => "[\n", footer => "\n]\n", interlude => ",\n",
          policy => {records_threshold => 2},
          filename_template => 'output-[% key %]-%03n.json',
          key => 'class',
       ],

       # Options, just flush the output to the sink
       { tap => 'sink' },
    )->([qw< mydata-04.txt >]);

### Dispatching, TIMTOWTDI

One drawback of the technique we saw in the previous sections about
dispatching is that, as a matter of fact, we have two dispatching
happening at two different times, i.e. at rendering and at writing. Many
times this might be what you actually need, but in our example it
actually limited us a bit, because it's somehow assuming that we want to
report errors as JSON structures, which is a bit overkill.

One alternative is to realize that the dispatcher's factory, and the
`filename_template` expansion is no exception, also receives the whole
record in addition to the key. Hence, we might modify the pipeline as
follows:

    use Data::Tubes qw< pipeline summon >;

    summon('Renderer::with_template_perlish');
    my $render_good = with_template_perlish(format =>
       '  {"name":"[% name %];"nick":"[% nick %]";"age":[% age %]}');
    # the "bad" renderer just complains about the nickname
    my $render_bad = with_template_perlish(format =>
       '  {"nick":"[% nick %]";"error":"invalid"}');

    pipeline(
       ['Source::iterate_files', open_file_args => {binmode => ':raw'}],
       'Reader::by_line',
       ['Parser::by_format', format => 'name;nick;age'],

       # let's put an intermediate step to "classify" the record
       sub {
          my $record;
          my $first_char = substr $record->{structured}{nick}, 0, 1;
          $record->{class} = ($first_char =~ m{[a-m]}mxs) ? 'lower'
                            :($first_char =~ m{[a-z]}imxs) ? 'other'
                            :                                'error';
          $record->{format} =
             ($record->{class} eq 'error') ? 'txt' : 'json';
          return $record;
       }

       # Rendering is wrapped by dispatch here
       ['Plumbing::dispatch', key => 'class',
          handlers => {
             lower => $render_good,
             other => $render_good,
             error => $render_bad,
          },
       ]

       # Printing, gets `rendered`, returns input unchanged
       ['Writer::dispatch_to_files',
          header => "[\n", footer => "\n]\n", interlude => ",\n",
          policy => {records_threshold => 2},
          filename_template =>
             'output-[% key %]-%03n.[% record.format %]',
          key => 'class',
       ],

       # Options, just flush the output to the sink
       { tap => 'sink' },
    )->([qw< mydata-04.txt >]);

### Sequence

In the previous section we solved our problem, but the solution might
still be considered a bit clunky. What if we need to have different
intermediate processing steps, depending on the specific record? For
example, we might want to avoid processing wrong records too much, but
do some additional mangling on good ones.

Enter `sequence` from `Data::Tubes::Plugin::Plumbing`. This function
is similar to `pipeline` --as a matter of fact, `pipeline` uses it
behind the scenes, and returns it if you don't provide any `tap`.

Hence, you can use dispatch to divide your flow across different
sequences, each with its own processing. Let's see how.

    use Data::Tubes qw< pipeline >;

    my $good = pipeline(
       ['Renderer::with_template_perlish', format =>
          '  {"name":"[% name %];"nick":"[% nick %]";"age":[% age %]}'],
       ['Writer::dispatch_to_files',
          header => "[\n", footer => "\n]\n", interlude => ",\n",
          policy => {records_threshold => 2},
          filename_template => 'output-[% key %]-%03n.json',
          key => 'class',
       ],
    ); # note... no tap here!

    my $bad = pipeline(
       sub { $_[0]{error}{message} = $_[0]{raw} },
       ['Renderer::with_template_perlish', format => "[% message %]\n",
          input => 'error',
       ],
       ['Writer:to_files', filename => 'ouput-exception-%t.txt']
    ); # note.. no tap here!

    pipeline(
       ['Source::iterate_files', open_file_args => {binmode => ':raw'}],
       'Reader::by_line',
       ['Parser::by_format', format => 'name;nick;age'],
       sub { # classification of input record
          my $record;
          my $first_char = substr $record->{structured}{nick}, 0, 1;
          $record->{class} = ($first_char =~ m{[a-m]}mxs) ? 'lower'
                            :($first_char =~ m{[a-z]}imxs) ? 'other'
                            :                                'error';
          return $record;
       }

       # Further processing depends on class
       ['Plumbing::dispatch', key => 'class',
          handlers => {
             lower => $good,
             other => $good,
             error => $bad,
          },
       ]

       # Options, just flush the output to the sink
       { tap => 'sink' },
    )->([qw< mydata-04.txt >]);

There are a few things going on here, let's take a look.

The first thing that pops out is that the renderer in `$bad` is using a
new parameter _input_, set to `error`. Quite suspiciously, the
renderer is preceded by a small tube that populates an `error` field in
the record... is this a coincidence?

It turns out that ["What Is A Record, Toolkit Style"](#what-is-a-record-toolkit-style) did not tell us
the whole story: all the tools in the toolkit can take a different
_input_ and produce a different _output_, all you have to do is to
specify the relevant key in the arguments to the factory function. So,
["What Is A Record, Toolkit Style"](#what-is-a-record-toolkit-style) actually describes the default
values for these parameters.

Of course, we might have just added `message` to the sub-hash
`structured`, but that would have been sort of cheating, wouldn't it?

The second thing is that, as anticipated, we managed to create two
different tracks for the input records, where the `Plumbing::dispatch`
does the split of the records stream across them. This allows each of
the sub-tube to be independent of each other (there are two here, they
might be many more of course). Note that `$good` and `$bad` are
created using `pipeline` (so that we avoid `summon`ing
`Plumbing::sequence` and shave off a few characters), taking care to
_avoid_ setting a `tap`, otherwise we wouldn't get a tube back!

## Process In Peace

Alas, we have come to the end of our journey through
[Data::Tubes](https://metacpan.org/pod/Data::Tubes). There's much more to
discover in the manual pages for each individual module: 

- [Data::Tubes](https://metacpan.org/pod/Data::Tubes)
- [Data::Tubes::Plugin::Parser](https://metacpan.org/pod/Data::Tubes::Plugin::Parser)
- [Data::Tubes::Plugin::Plumbing](https://metacpan.org/pod/Data::Tubes::Plugin::Plumbing)
- [Data::Tubes::Plugin::Reader](https://metacpan.org/pod/Data::Tubes::Plugin::Reader)
- [Data::Tubes::Plugin::Renderer](https://metacpan.org/pod/Data::Tubes::Plugin::Renderer)
- [Data::Tubes::Plugin::Source](https://metacpan.org/pod/Data::Tubes::Plugin::Source)
- [Data::Tubes::Plugin::Util](https://metacpan.org/pod/Data::Tubes::Plugin::Util)
- [Data::Tubes::Plugin::Writer](https://metacpan.org/pod/Data::Tubes::Plugin::Writer)
- [Data::Tubes::Util](https://metacpan.org/pod/Data::Tubes::Util)
- [Data::Tubes::Util::Output](https://metacpan.org/pod/Data::Tubes::Util::Output)

If you want to contribute, [Data::Tubes](https://metacpan.org/pod/Data::Tubes) is on GitHub at
[https://github.com/polettix/Data-Tubes](https://github.com/polettix/Data-Tubes). One way to contribute might
be releasing your own plugins... e.g. if you prefer to use [Template](https://metacpan.org/pod/Template)
instead of [Template::Perlish](https://metacpan.org/pod/Template::Perlish)!
