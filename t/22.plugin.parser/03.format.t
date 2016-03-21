use strict;
use Test::More;
use Data::Dumper;

use Text::Tubes qw< summon >;

summon('+Parser::parse_by_format');
ok __PACKAGE__->can('parse_by_format'), "summoned parse_by_format";

my $expected = {
   what => 'a',
   ever => 'b',
   you  => 'ccccccc',
   'do' => 'd',
};
for my $pair (
   ['what|ever|you|do', 'a|b|ccccccc|d'],
   ['what:ever;you/do', 'a:b;ccccccc/d'],
  )
{
   my ($format, $string) = @$pair;

   {
      my $parser = parse_by_format(
         input  => undef,
         output => undef,
         format => $format
      );
      my $outcome = $parser->($string);
      is ref($outcome), 'HASH', 'outcome is a hash';
      ok exists($outcome->{record}), 'outcome has a record field';
      my $record = $outcome->{record};
      is ref($record), 'HASH', 'record is a hash';
      is_deeply $record, $expected, 'parsed by format';
   }

   {
      my $parser = parse_by_format(
         output => undef,
         format => $format
      );
      my $outcome = $parser->({raw => $string});
      is ref($outcome), 'HASH', 'outcome is a hash';
      ok exists($outcome->{record}), 'outcome has a record field';
      my $record = $outcome->{record};
      is ref($record), 'HASH', 'record is a hash';
      is_deeply $record, $expected, 'parsed by format';
   }

   {
      my $parser = parse_by_format(
         input  => 'karb',
         output => undef,
         format => $format
      );
      my $outcome = $parser->({karb => $string});
      is ref($outcome), 'HASH', 'outcome is a hash';
      ok exists($outcome->{record}), 'outcome has a record field';
      my $record = $outcome->{record};
      is ref($record), 'HASH', 'record is a hash';
      is_deeply $record, $expected, 'parsed by format';
   }

   {
      my $parser = parse_by_format(format => $format);
      my $outcome = $parser->({raw => $string});
      is ref($outcome), 'HASH', 'outcome is a hash';
      ok exists($outcome->{record}), 'outcome has a record field';
      my $record = $outcome->{record};
      is ref($record), 'HASH', 'record is a hash';
      is_deeply $record, {structured => $expected, raw => $string},
        'parsed by format';
   }

} ## end for my $pair (['what|ever|you|do'...])
done_testing();
