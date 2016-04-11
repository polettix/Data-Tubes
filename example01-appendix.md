---
title: "Data::Tubes"
layout: page
author: polettix
tagline: "Let's Marry! Appendix"
comments: true
---

# Data::Tubes Example - Let's Marry! Appendix

Here you will find a session of using the program explained in [Let's
Marry](example01.html), enjoy!

## Program

You can download [weddinv](example01/weddinv). It does not make much
sense to expand it here though!

## Template File

[mail.tp](example01/mail.tp):

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

## Input Data File

[guests.txt](example01/guests.txt):

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

## Execution with Input Data File

Let's try to run the program without parameters:

```
shell$ ./weddinv
missing options place
Usage:
       weddinv [--usage] [--help] [--man] [--version]

       weddinv
```

As a matter of fact, we were not able to put a default place yet, so we
must provide one. It's also quite evident that we need to fill the POD
in... This is left as an excercise!

```
shell$ ./weddinv --place 'our home'
shell$ ls -l
drwxr-xr-x 2 foo bar   4096 Apr 11 08:55 close-friends
-rw-r--r-- 1 foo bar    387 Apr 11 07:34 guests.txt
-rw-r--r-- 1 foo bar    598 Apr 11 07:45 mail.tp
drwxr-xr-x 2 foo bar   4096 Apr 11 08:55 nice-relatives
-rwxr-xr-x 1 foo bar 105067 Apr 11 08:54 weddinv
shell$ ls -l close-friends nice-relatives
close-friends:
total 8
-rw-r--r-- 1 foo bar 292 Apr 11 08:57 invitation-00.txt
-rw-r--r-- 1 foo bar 462 Apr 11 08:57 invitation-01.txt

nice-relatives:
total 4
-rw-r--r-- 1 foo bar 482 Apr 11 08:57 invitation-00.txt
```

The two directories `close-friends` and `nice-relatives` were created,
in line with our expectations (one directory for each group found).
There are some files inside, and hopefully they are one for each guest.

[close-friends/invitation-00.txt](example01/close-friends/invitation-00.txt):

```
Hi Juliet,

   we would like to invite you at our wedding that will be celebrated on
April 1st, 2018 at our home.

It would be a pleasure for us to enjoy the dinner with you at
Restaurant Bui-a-Car. If you plan to attend, it would be nice of
you to let us know.

Cheers,

   Silvia & Flavio.
```

Good! We found only one invitation letter, and it does not contain any
reference to the hotel because Juliet lives in our same city.

[close-friends/invitation-01.txt](example01/close-friends/invitation-01.txt):

```
Hi John,

   we would like to invite you at our wedding that will be celebrated on
April 1st, 2018 at our home.

It would be a pleasure for us to enjoy the dinner with you at
Restaurant Bui-a-Car. If you plan to attend, it would be nice of
you to let us know.

It would also be a pleasure for us if you will be our guest at
Hotel Namaddormi. Please let us know the date you plan to come visit
us for arranging the booking properly!

Cheers,

   Silvia & Flavio.
```

This seems good as well.


[nice-relatives/invitation-00.txt](example01/nice-relatives/invitation-02.txt):

```
Hello Aunt Jean & Uncle John,

   we would like to invite you at our wedding that will be celebrated on
April 1st, 2018 at our home.

It would be a pleasure for us to enjoy the dinner with you at
Restaurant Bui-a-Car. If you plan to attend, it would be nice of
you to let us know.

It would also be a pleasure for us if you will be our guest at
Hotel Namaddormi. Please let us know the date you plan to come visit
us for arranging the booking properly!

Yours,

   Silvia & Flavio.
```

This seems good as well. Note that the salutations are different for our
old Aunt and Uncle!


## Wrong Input Data File

Here's an example of a *wrong* data file
[guests-wrong.txt](example01/guests-wrong.txt):

```
# Each line is: name;group;initial;final;dinner?;hotel?

# nice relatives, coming from outside
Aunt Jean & Uncle John;nice-relatives;Hello;Yours;1;1

# Friends we want for sure. Juliet and John live in our city
Juliet;close-friends;Hi;Cheers;1;0
John;close-friends;Hi;Cheers;1;1

# We're not sure about Max, so it's commented out
#Max;acquaintances;Dear;Regards;0;0

# the following line is wrong, it's missing the group!
Bernie;Dear;Regards;0;0

# and
# so
# on...

```

Note that the line regarding Bernie is wrong, because it's missing a
field (the group, in particular).

## Execution with Wrong Input Data File

Before using the new *wrong* input data file, we will do some cleanup:

```
shell$ rm -rf close-friends nice-relatives
```

We can use command line option `--input` (or `--data` or `-i`) to
override the default input file:

```
shell$ ./weddinv --place 'our home' --input guests-wrong.txt
[2016/04/11 09:17:43] [FATAL] $VAR1 = {
  'message' => '\'parse by split\': invalid record, expected 6 items, got 5',
  'record' => {
    'raw' => 'Bernie;Dear;Regards;0;0',
    'source' => {
      'type' => 'file',
      'input' => 'guests-wrong.txt',
      'fh' => \*{'Data::Tubes::Plugin::Source::'},
      'name' => 'file:guests-wrong.txt'
    }
  },
  'input' => 'raw'
};

shell$ ls -l
total 124
-rw-r--r-- 1 foo bar    387 Apr 11 07:34 guests.txt
-rw-r--r-- 1 foo bar    467 Apr 11 08:05 guests-wrong.txt
-rw-r--r-- 1 foo bar    598 Apr 11 07:45 mail.tp
drwxr-xr-x 2 foo bar   4096 Apr 11 09:19 nice-relatives
-rwxr-xr-x 1 foo bar 105067 Apr 11 08:54 weddinv
```

Ouch! It seems that we lost our close friends! This happened because we
got an exception after the processing or our beloved nice relatives, but
before our close friends.

Is this a good or a bad thing? It's up to you to decide. In this case,
it's probably fine, because you get to know about errors in your data
file and you can correct them straight away.

Other times, you will not have control over your inputs, and you might
want to let the show go on even in case a few records are not compliant
with your specification. If this is the case, take a good look at
["fallback" in
Data::Tubes::Plugin::Plumbing](https://metacpan.org/pod/distribution/Data-Tubes/lib/Data/Tubes/Plugin/Plumbing.pod#fallback)
because it might be exactly what you are after.

## That's All Folks!

Did you enjoy this ride? Let us know in the comments!
