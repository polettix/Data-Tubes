#!/usr/bin/env perl
use strict;
use warnings;
use Template::Perlish ();
use Path::Tiny;
use 5.010;

my ($distro, $version) = @ARGV;
my $dp    = path($distro);
my $local = path(qw< local lib perl5 >);

my $tubergen = path(qw< script tubergen.tp >)->slurp_raw();
my $tuber    = path(qw< script tuber.tp >)->slurp_raw();
my $scriptd  = $dp->child('script');
$scriptd->mkpath();
my $target   = $scriptd->child(qw< tubergen >);

my @modules = (
   [
      'Log/Log4perl/Tiny.pm',
      $local->child(qw< Log Log4perl Tiny.pm >)->slurp_raw()
   ],
   [
      'Template/Perlish.pm',
      $local->child(qw< Template Perlish.pm >)->slurp_raw()
   ],
   ['Try/Tiny.pm', $local->child(qw< Try Tiny.pm >)->slurp_raw()],
);

my $iter = $dp->child('lib')->iterator({recurse => 1});
while (my $path = $iter->()) {
   next unless $path->stringify() =~ m{\.pm$}mxs;
   my $name = $path->relative($dp->child('lib'))->stringify();
   push @modules, [$name, $path->slurp_raw()];
}

my $tp = Template::Perlish->new(
   start => '{{[',
   stop  => ']}}'
);
my $rendered = $tp->process(
   $tubergen,
   {
      distro  => $distro,
      modules => \@modules,
      tuber   => $tuber,
      version => $version,
   },
);
$target->spew_raw($rendered);
$target->chmod('a+x');
$target->copy(qw< script tubergen >)->chmod('a+x');
