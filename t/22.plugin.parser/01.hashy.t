use strict;
use Test::More;
use Data::Dumper;

use Text::Tubes qw< summon >;

summon('+Parser::parse_hashy');
ok __PACKAGE__->can('parse_hashy'), "summoned parse_hashy";

{
   my $parser =
     parse_hashy(input => undef, output => undef, default_key => 'mu');
   my $outcome = $parser->('what=ever you=like whatever');
   is ref($outcome), 'HASH', 'outcome is a hash';
   ok exists($outcome->{record}), 'outcome has a record field';
   my $record = $outcome->{record};
   is ref($record), 'HASH', 'record is a hash';
   is_deeply $record, {qw< what ever you like mu whatever >},
     'hash was parsed';
}

{
   my $parser = parse_hashy(output => undef, default_key => 'mu');
   my $outcome = $parser->({raw => 'what=ever you=like whatever'});
   is ref($outcome), 'HASH', 'outcome is a hash';
   ok exists($outcome->{record}), 'outcome has a record field';
   my $record = $outcome->{record};
   is ref($record), 'HASH', 'record is a hash';
   is_deeply $record, {qw< what ever you like mu whatever >},
     'hash was parsed';
}

{
   my $parser =
     parse_hashy(input => 'karb', output => undef, default_key => 'mu');
   my $outcome = $parser->({karb => 'what=ever you=like whatever'});
   is ref($outcome), 'HASH', 'outcome is a hash';
   ok exists($outcome->{record}), 'outcome has a record field';
   my $record = $outcome->{record};
   is ref($record), 'HASH', 'record is a hash';
   is_deeply $record, {qw< what ever you like mu whatever >},
     'hash was parsed';
}

{
   my $parser  = parse_hashy(default_key => 'mu');
   my $raw     = 'what=ever you=like whatever';
   my $outcome = $parser->({raw => $raw});
   is ref($outcome), 'HASH', 'outcome is a hash';
   ok exists($outcome->{record}), 'outcome has a record field';
   my $record = $outcome->{record};
   is ref($record), 'HASH', 'record is a hash';
   is_deeply $record,
     {structured => {qw< what ever you like mu whatever >}, raw => $raw},
     'hash was parsed';
}

done_testing();
