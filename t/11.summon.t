use strict;
use Test::More;
use Data::Dumper;

use Text::Tubes qw< summon >;

my $files = __PACKAGE__->can('sequence');
ok !$files, 'sub "sequence" does not exist initially';

summon('+Plumbing::sequence');
$files = __PACKAGE__->can('sequence');
ok $files, 'sub "sequence" summoned';

my $tube = __PACKAGE__->can('traverse');
ok !$tube, 'sub "traverse" does not exist initially';

summon('Text::Tubes::Util::traverse');
$tube = __PACKAGE__->can('traverse');
ok $tube, 'sub "traverse" summoned';

done_testing();
