#!/usr/bin/env perl
use strict;
use warnings;
use Template::Perlish ();
use Path::Tiny;
use 5.010;

my ($distro, $version) = @ARGV;
my $podfile = path($distro)->child(qw< lib Data Tubes.pod >);

my $tp = Template::Perlish->new(
   start => '{{[',
   stop  => ']}}',
   variables => {
      distro => $distro,
      version => $version,
   },
);
my $rendered = $tp->process($podfile->slurp_raw());
$podfile->spew_raw($rendered);
