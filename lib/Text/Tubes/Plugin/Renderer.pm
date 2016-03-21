package Text::Tubes::Plugin::Parser;
use strict;
use warnings;
use English qw< -no_match_vars >;

use Log::Log4perl::Tiny qw< :easy :dead_if_first >;

use Text::Tubes::Util
  qw< assert_all_different metadata normalize_args test_all_equal unzip >;
my %global_defaults = (
   input  => 'raw',
   output => 'structured',
);

