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

summon([qw< +Reader read_by_line read_by_paragraph read_by_separator >]);
ok __PACKAGE__->can('read_by_line'),      'summoned by_line';
ok __PACKAGE__->can('read_by_paragraph'), 'summoned by_paragraph';
ok __PACKAGE__->can('read_by_separator'), 'summoned by_separator';

summon({'+Source' => [qw< open_file iterate_files iterate_array >]});
ok __PACKAGE__->can('open_file'),      'summoned open_file';
ok __PACKAGE__->can('iterate_files'), 'summoned iterate_files';
ok __PACKAGE__->can('iterate_array'), 'summoned iterate_array';

done_testing();
