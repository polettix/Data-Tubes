use strict;
use Test::More;
use Data::Dumper;

use Text::Tubes qw< summon >;

my @functions = qw<
  parse_by_format
  parse_by_regex
  parse_by_regexes
  parse_by_split
  parse_hashy
  parse_single
>;
summon({'+Parser' => \@functions,});
ok __PACKAGE__->can($_), "summoned $_" for @functions;

done_testing();
