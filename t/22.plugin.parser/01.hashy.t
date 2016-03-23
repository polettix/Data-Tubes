use strict;
use Test::More;
use Data::Dumper;

use Data::Tubes qw< summon >;

summon('+Parser::parse_hashy');
ok __PACKAGE__->can('parse_hashy'), "summoned parse_hashy";

my $raw     = 'what=ever you=like whatever';
{
   my $parser  = parse_hashy(default_key => 'mu');
   my $outcome = $parser->({raw => $raw});
   is ref($outcome), 'HASH', 'outcome is a hash';
   ok exists($outcome->{record}), 'outcome has a record field';
   my $record = $outcome->{record};
   is ref($record), 'HASH', 'record is a hash';
   is_deeply $record,
     {structured => {qw< what ever you like mu whatever >}, raw => $raw},
     'hash was parsed';
}

{
   my $parser =
     parse_hashy(input => 'karb', output => 'what', default_key => 'mu');
   my $outcome = $parser->({karb => $raw});
   is ref($outcome), 'HASH', 'outcome is a hash';
   ok exists($outcome->{record}), 'outcome has a record field';
   my $record = $outcome->{record};
   is ref($record), 'HASH', 'record is a hash';
   is_deeply $record,
     {what => {qw< what ever you like mu whatever >}, karb => $raw},
     'hash was parsed';
}

done_testing();
