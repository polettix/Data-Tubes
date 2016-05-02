#!/usr/bin/env perl
use strict;
use warnings;
use Template::Perlish ();
use Path::Tiny;
use 5.010;

my ($distro, $version) = @ARGV;
my $podfile = path($distro)->child(qw< lib Data Tubes.pod >);
my $readme  = path($distro)->child('README');

my $tp = Template::Perlish->new(
   start => '{{[',
   stop  => ']}}',
   variables => {
      distro => $distro,
      version => $version,
   },
);

for my $file ($podfile, $readme) {
   my $rendered = $tp->process($file->slurp_raw());
   $file->spew_raw($rendered);
}
