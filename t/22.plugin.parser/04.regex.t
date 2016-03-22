use strict;
use Test::More;
use Data::Dumper;

use Text::Tubes qw< summon >;

summon('+Parser::parse_by_regex');
ok __PACKAGE__->can('parse_by_regex'), "summoned parse_by_regex";

my $expected = {
   what => 'ever',
   you  => 'like',
   to   => 'do',
};
my $string = '<<ever>> >like< "do"';
my $regex  = qr{(?mxs: 
   \A
      <<(?<what>.*?)>> \s+
      >(?<you>.*?)< \s+
      "(?<to>.*?)"
   \z)};

{
   my $parser = parse_by_regex(regex => $regex);
   my $outcome = $parser->({raw => $string});
   is ref($outcome), 'HASH', 'outcome is a hash';
   ok exists($outcome->{record}), 'outcome has a record field';
   my $record = $outcome->{record};
   is ref($record), 'HASH', 'record is a hash';
   is_deeply $record, {structured => $expected, raw => $string},
     'hash was parsed via regex';
}

{
   my $parser =
     parse_by_regex(regex => $regex, input => 'foo', output => 'bar');
   my $outcome = $parser->({foo => $string});
   is ref($outcome), 'HASH', 'outcome is a hash';
   ok exists($outcome->{record}), 'outcome has a record field';
   my $record = $outcome->{record};
   is ref($record), 'HASH', 'record is a hash';
   is_deeply $record, {bar => $expected, foo => $string},
     'hash was parsed via regex';
}

done_testing();
