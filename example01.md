---
title: "Data::Tubes"
layout: page
author: polettix
tagline: "Let's Marry!"
comments: true
---

# Let's Marry!

You're planning to marry and you have to think about invitations!

Let's make a program that generates wedding invitations for a list of
recipients, each to be put in its own file but divided into directories
based on how well you know people (you are doing some maths still, so
you want to be sure to invite your parents but still be able to quickly
cut a few groups of distant and not-so-nice relatives).

We will proceed as follows:

- we will craft an invitation letter template;
- we will figure out an input data format and populate a file according
  to it
- we will generate a program to join the two via Data::Tubes.


## Invitation Letter Template

We have a few different categories of guests, so our invitation will be
different depending on:

- how close we are: some will be greeted with a simple *Hi*, other ones
  with a more formal *Dearest*;
- the recipents' name(s), of course
- wedding details like date, place and dinner place, that are stillin a
  state of flux
- whether the guest is also invited to the dinner or not
- whether the guest will be hosted in a hotel or not (people we invite
  from a distant city).

The template for the invitation letter is the following:

```
[% initial_salutation %] [% name %],

   we would like to invite you at our wedding that will be celebrated on
[% wedding.date %] at [% wedding.place %].

[%
    if (V 'dinner') { 

%]It would be a pleasure for us to enjoy the dinner with you at
[% wedding.dinner %]. If you plan to attend, it would be nice of
you to let us know.

[% 
    }

    if (V 'hotel') {

%]It would also be a pleasure for us if you will be our guest at
[% wedding.hotel %]. Please let us know the date you plan to come visit
us for arranging the booking properly!

[%
    }
%][% final_salutation %],

   Silvia & Flavio.
```

(In case you're wondering yes, I had a similar invitation letter for my
wedding, but I hade to endure the lack of Data::Tubes).


## Input Data

Input data are needed for different reasons:

- some parameters are needed for the template
- some are needed for proper output files division
- some are guest-specific, other ones are wedding specific

We will put all guest-specific data in a file, while we will input
wedding-specific data as command-line options.

The following variables are needed for each guest:

- the `name`
- the `group` they belong to
- the `initial_salutation`
- a boolean flag to track `dinner`
- a boolean flag to track `hotel` needs
- the `final_salutation`

We will use a simple semicolon-separated format, but we want to have the
ability to comment lines quickly to exclude people we're not sure about
or just to have a header that reminds us the order of the fields. We
also want empty lines to have a clean input.

Our example file will be the following:

```
# Each line is: name;group;initial;final;dinner?;hotel?

# nice relatives, coming from outside
Aunt Jean & Uncle John;nice-relatives;Hello;Yours;1;1

# Friends we want for sure. Juliet and John live in our city
Juliet;close-friends;Hi;Cheers;1;0
John;close-friends;Hi;Cheers;1;1

# We're not sure about Max, so it's commented out
#Max;acquaintances;Dear;Regards;0;0

# and
# so
# on...
```

## Mint Program

Time to generate and populate the program! Use [tubergen](tubergen) and
you will be all set. We will call our program `weddinv`:

```
shell$ tubergen -n weddinv -A 'wedding invitations' -a me -e me@example.com
shell$ ls -l weddinv
-rwxr-xr-x 1 foo bar 105418 Apr 10 19:35 weddinv
```

So, our program is there waiting for us, already executable! Let's start
fleshing it out.

## Adjust Preamble

We will use function `Util::read_file` to slurp the template, so we will
also import `summon`:

```
RUSE('Data::Tubes', qw< pipeline summon >);
```

## Command-line Options

We want to accept the following options:

- wedding date, place, dinner place and hotel, with the following
  defaults as we already have some ideas/preferences:
    - date: April 1st, 2018
    - dinner: Restaurant Bui-a-Car
    - hotel: Hotel Namaddormi
- template file
- data file

Here's the relevant section:

```
my %config = get_options(
   ['loglevel|log=s', default => 'INFO'],

   # wedding-related
   ['date|d=s',   default  => 'April 1st, 2018'],
   ['dinner|D=s', default  => 'Restaurant Bui-a-Car'],
   ['hotel|h=s',  default  => 'Hotel Namaddormi'],
   ['place|p=s',  required => 1], # no default available

   # inputs
   ['data|input|i=s', default => 'guests.txt'],
   ['template|t=s',   default => 'mail.tp'],
);
```

## Logic

At this point, we only have to code the logic. Data will come from a
file, line by line; we have to filter out empty lines and comments, to
only parse the other ones. The output will the be fed to a renderer that
will use the template to produce a letter for each recipient, then we
have to save each letter in the appropriate location. Let's start!

Handling the input from the file and the initial reading process is
simple through the plugins. We're dealing with one single input file, so
`Source::open_file` will be sufficient, followed by the line-by-line
reader:

```
pipeline(
   'Source::open_file',
   'Reader::by_line',
   ...
   {tap => 'sink'},
)->($config{data});
```

Now the reader puts the line in field `raw`, so we can filter it to
eliminate empty lines and comments:


```
sub { return ($_[0]{raw} =~ m{^ \s* (?: \# | $)}mxs) ? () : $_[0]; },
```

We're ready for parsing at this point. The input format is simple and we
can use the `Parser::by_format` as we have fixed columns:

```
['Parser::by_format', format =>
 'name;group;initial_salutation;final_salutation;dinner;hotel'],
```

Now our guest's data are in the `structured` sub-hash. It's time to load
the template and pre-define the wedding-based parameters from the
command line. We will rely upon `Util::read_file`:

```
summon('Util::read_file');
...
['Renderer::with_template_perlish',
 template => read_file(filename => $config{template}),
 variables => {
    wedding => {
       date   => $config{date},
       dinner => $config{dinner},
       hotel  => $config{hotel},
       place  => $config{place},
    }
 }
],
```

In this case, the template is using the default start and stop markers
so we don't need to set them explicitly.

At this point, we're only missing the saving to a file part. We will use
`Writer::dispatch_to_files` as it provides us the flexibility for doing
all that we need:

- we will use the `group` element as a key to differentiate across
  different output directories;
- we will set a policy with a threshold of 1 single record, so that each
  message will fit into its own file.

Here's what we can come with:

```
['Writer::dispatch_to_files',
 filename_template => '[% key %]/invitation-%02n.txt',
 key => [qw< structured group >],
 policy => {records_threshold => 1},
],
```

We're ready to put all the pieces together:

```
summon('Util::read_file');
pipeline(
   'Source::open_file',
   'Reader::by_line',
   sub { return ($_[0]{raw} =~ m{^ \s* (?: \# | $)}mxs) ? () : $_[0]; },
   ['Parser::by_format', format =>
     'name;group;initial_salutation;final_salutation;dinner;hotel'],
   ['Renderer::with_template_perlish',
     template => read_file(filename => $config{template}),
     variables => {
        wedding => {
        date   => $config{date},
        dinner => $config{dinner},
        hotel  => $config{hotel},
        place  => $config{place},
        }
     }
   ],
   ['Writer::dispatch_to_files',
     filename_template => '[% key %]/invitation-%02n.txt',
     key    => [qw< structured group >],
     policy => {records_threshold => 1},
   ],
   {tap => 'sink'},
)->($config{data});
```

We only have to run it at this point!

## Trapping Exceptions

There is more to it!

One of the possible area that you might want to investigate is exception
handling for example. Suppose that you add a new field in your data, but
forget to correct a line in your input file: this will make
`Parser::by_format` complain loudly, throwing an exception.

Alas, this exception comes in the form of a hash reference, so this is
what you will see, more or less:

```
shell$ weddinv --place 'my house'
HASH(0x8b3e858)
```

Thanks to the batteries included, you can immediately wrap the whole
call to `pipeline` in a `try`/`catch` block, and use `Data::Dumper`:

```
try {
   pipeline(...)->($config{data});
}
catch {
   use Data::Dumper; local $Data::Dumper::Indent = 1;
   LOGDIE(Dumper($_));
};
```

Here's what we would get:

```
[2016/04/11 08:08:44] [FATAL] $VAR1 = {
   'message' => '\'parse by split\': invalid record, expected 6 items, got 5',
   'record' => {
     'raw' => 'Bernie;Dear;Regards;0;0',
     'source' => {
       'name' => 'file:guests-wrong.txt',
       'type' => 'file',
       'input' => 'guests-wrong.txt',
       'fh' => \*{'Data::Tubes::Plugin::Source::'}
     }
   },
   'input' => 'raw'
};
```

There is full indication of what happened, where in the input... you
might be tempted to wrap the whole thing using some plumbing for
exception handling, but this will be up to you!

## Run

We don't want to clutter this article with a full run, but if you're
interested into it you can take a look at the
[appendix](example01-appendix).

## Final Remarks

This is the total amount of *code* that we wrote:

```
# ...
RUSE('Data::Tubes', qw< pipeline summon >);
# ...
my %config = get_options(
   ['loglevel|log=s', default => 'INFO'],

   # wedding-related
   ['date|d=s',   default => 'April 1st, 2018'],
   ['dinner|D=s', default => 'Restaurant Bui-a-Car'],
   ['hotel|h=s',  default => 'Hotel Namaddormi'],
   ['place|p=s',  required => 1], # no default available

   # inputs
   ['data|input|i=s', default => 'guests.txt'],
   ['template|t=s',   default => 'mail.tp'],
);
# ...
summon('Util::read_file');
try {
   pipeline(
      'Source::open_file',
      'Reader::by_line',
      sub { return ($_[0]{raw} =~ m{^ \s* (?: \# | $)}mxs) ? () : $_[0]; },
      ['Parser::by_format', format =>
        'name;group;initial_salutation;final_salutation;dinner;hotel'],
      ['Renderer::with_template_perlish',
        template => read_file(filename => $config{template}),
        variables => {
          wedding => {
            date   => $config{date},
            dinner => $config{dinner},
            hotel  => $config{hotel},
            place  => $config{place},
          }
        }
      ],
      ['Writer::dispatch_to_files',
        filename_template => '[% key %]/invitation-%02n.txt',
        key    => [qw< structured group >],
        policy => {records_threshold => 1},
      ],
      {tap => 'sink'},
   )->($config{data});
}
catch {
   use Data::Dumper; local $Data::Dumper::Indent = 1;
   LOGEXIT(Dumper($_));
};
# ...
```

It's not bad considering all it does: flexible way of reading its
inputs, rendering, saving into the right files in the right places, all
with automatic error control.

The thing that we did not do, but you SHOULD always, is write the
documentation for our program. It's not difficult to do, and it will
save you the annoyance to always try to figure out what it does later.

One of the key elements to allowing us doing this is
[tubergen](tubergen), as it provided us a good starting point to avoid
dealing with the boilerplate and just get into coding. The nice side
effect of all the embedding is that the program you end up with is ready
to be deployed elsewhere and, as long as Perl 5.10 or better is there,
you can start using it.

Did you enjoy the ride? Let us know in the comments!
