---
title: 'Data::Tubes'
layout: page
author: polettix
tagline: 'The Missing Manual'
comments: true
---

# Data::Tubes - Tubergen

[tubergen](https://github.com/polettix/Data-Tubes/raw/master/script/tubergen)
is a little program that helps you get up to speed with
[Data::Tubes](https://github.com/polettix/Data-Tubes/). Is't nothing more
than a minting program.

You would normally run it from the command line like this:

```
$ tubergen \
    --name my-tubes \
    --output my-tubes \
    --abstract 'My Tubes' \
    --author 'A. U. Thor' \
    --email author@example.com
```

You MUST provide all parameters, apart from `output` that defaults to
standard output.

What you get back is a Perl program that has all relevant components for
using Data::Tubes inside, including [Template::Perlish](),
[Log::Log4perl::Tiny]() and [Try::Tiny]() (this being normally optional,
but a good thing to have around).

The program is structured as follows:

- a *preamble* where all the housekeeping is done to let you use
  Data::Tubes and the modules that are shipped with it;
- a *command line handing* section where you can define the input options
  for your program;
- a *business logic* section where you are supposed to put all your logic,
  leveraging on the shipped modules and whatever else you see fit
- an *embedded modules* sections where all the shipped modules are packed
  and loaded automatically for you
- a *POD* section where you can describe what your program does, which
  options it accepts, and so forth.

The following sections will guide you through each of these parts.

## Preamble

## Command Line Handling

## Business Logic

## Embedded Modules

## POD


