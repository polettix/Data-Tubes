#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use Pod::Usage qw< pod2usage >;
use Getopt::Long qw< :config gnu_getopt >;
use English qw< -no_match_vars >;
my $VERSION = '0.0.1';
use Path::Tiny;
use lib path(__FILE__)->parent(2)->child('lib')->stringify();
use Text::Tubes qw< drain summon >;
use Log::Log4perl::Tiny qw< :easy LOGLEVEL >;

my %config = (
   output   => '-',
   loglevel => 'INFO',
);
GetOptions(
   \%config,
   qw<
     usage! help! man! version!
     output|o=s
     loglevel|l=s
     >
) or pod2usage(-verbose => 99, -sections => 'USAGE');
pod2usage(message => "$0 $VERSION", -verbose => 99, -sections => ' ')
  if $config{version};
pod2usage(-verbose => 99, -sections => 'USAGE') if $config{usage};
pod2usage(-verbose => 99, -sections => 'USAGE|EXAMPLES|OPTIONS')
  if $config{help};
pod2usage(-verbose => 2) if $config{man};

# Script implementation here
LOGLEVEL $config{loglevel};
my @inputs = @ARGV ? @ARGV : '-';
my $output = $config{output};

INFO 'starting';

summon(
   [qw< +Plumbing sequence sink >],
   [qw< +Source iterate_files >],
   [qw< +Reader read_by_line >],
   [qw< +Parser parse_hashy >],
   [qw< +Renderer render_with_template_perlish >],
   [qw< +Writer write_to_file >],
);

my $template = <<'END';
Hello [% name %], [% question %]?
END

drain(
   sequence(
      tubes => [
         iterate_files(files => \@inputs),
         read_by_line(),
         parse_hashy(chunks_separator => '|'),
         render_with_template_perlish(template => $template),
         write_to_file(filename => $output),
      ],
   )
);

INFO 'ending';
