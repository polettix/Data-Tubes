use strict;

# vim: ts=3 sts=3 sw=3 et ai :

use Test::More;
use Data::Dumper;

use Data::Tubes qw< summon >;

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
      my $parser = parse_by_format(format => $format);
      my $record = $parser->({raw => $string});
      is ref($record), 'HASH', 'record is a hash';
      is_deeply $record, {structured => $expected, raw => $string},
        'parsed by format';
   }

   {
      my $parser = parse_by_format(
         format => $format,
         input  => 'foo',
         output => 'bar'
      );
      my $record = $parser->({foo => $string});
      is ref($record), 'HASH', 'record is a hash';
      is_deeply $record, {bar => $expected, foo => $string},
        'parsed by format';
   }

} ## end for my $pair (['what|ever|you|do'...])
done_testing();
