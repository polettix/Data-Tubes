use strict;
use Test::More;
use Data::Dumper;

use Text::Tubes qw< summon >;

my $files = __PACKAGE__->can('files');
ok !$files, 'sub "files" does not exist initially';

summon('+Reader::files');
$files = __PACKAGE__->can('files');
ok $files, 'sub "files" summoned';

my $tube = __PACKAGE__->can('tube');
ok !$tube, 'sub "tube" does not exist initially';

summon('Text::Tubes::tube');
$tube = __PACKAGE__->can('tube');
ok $tube, 'sub "tube" summoned';

done_testing();
