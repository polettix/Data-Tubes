use strict;
use Test::More;
use Data::Dumper;

use Data::Tubes qw< summon >;

summon('+Parser::parse_single');
ok __PACKAGE__->can('parse_single'), "summoned parse_single";

my $string = 'what=ever you=like whatever';
{
   my $parser = parse_single(key => 'mu');
   my $outcome = $parser->({raw => $string});
   is ref($outcome), 'HASH', 'outcome is a hash';
   ok exists($outcome->{record}), 'outcome has a record field';
   my $record = $outcome->{record};
   is ref($record), 'HASH', 'record is a hash';
   is_deeply $record,
     {structured => {mu => $string}, raw => $string}, 'single was parsed';
}

{
   my $parser = parse_single(input => 'foo', output => 'bar', key => 'mu');
   my $outcome = $parser->({foo => $string});
   is ref($outcome), 'HASH', 'outcome is a hash';
   ok exists($outcome->{record}), 'outcome has a record field';
   my $record = $outcome->{record};
   is ref($record), 'HASH', 'record is a hash';
   is_deeply $record,
     {bar => {mu => $string}, foo => $string}, 'single was parsed';
}

done_testing();
