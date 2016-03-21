use strict;
use Test::More;
use Data::Dumper;

use Text::Tubes qw< summon >;

summon('+Parser::parse_single');
ok __PACKAGE__->can('parse_single'), "summoned parse_single";

my $string = 'what=ever you=like whatever';
{
   my $parser =
     parse_single(input => undef, output => undef, key => 'mu');
   my $outcome = $parser->($string);
   is ref($outcome), 'HASH', 'outcome is a hash';
   ok exists($outcome->{record}), 'outcome has a record field';
   my $record = $outcome->{record};
   is ref($record), 'HASH', 'record is a hash';
   is_deeply $record, {mu => $string}, 'single was parsed';
}

{
   my $parser = parse_single(output => undef, key => 'mu');
   my $outcome = $parser->({raw => $string});
   is ref($outcome), 'HASH', 'outcome is a hash';
   ok exists($outcome->{record}), 'outcome has a record field';
   my $record = $outcome->{record};
   is ref($record), 'HASH', 'record is a hash';
   is_deeply $record, {mu => $string}, 'single was parsed';
}

{
   my $parser =
     parse_single(input => 'karb', output => undef, key => 'mu');
   my $outcome = $parser->({karb => $string});
   is ref($outcome), 'HASH', 'outcome is a hash';
   ok exists($outcome->{record}), 'outcome has a record field';
   my $record = $outcome->{record};
   is ref($record), 'HASH', 'record is a hash';
   is_deeply $record, {mu => $string}, 'single was parsed';
}

{
   my $parser  = parse_single(key => 'mu');
   my $outcome = $parser->({raw => $string});
   is ref($outcome), 'HASH', 'outcome is a hash';
   ok exists($outcome->{record}), 'outcome has a record field';
   my $record = $outcome->{record};
   is ref($record), 'HASH', 'record is a hash';
   is_deeply $record,
     {structured => {mu => $string}, raw => $string}, 'single was parsed';
}


done_testing();
