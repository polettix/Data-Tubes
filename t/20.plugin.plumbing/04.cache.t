use strict;

# vim: ft=perl ts=3 sts=3 sw=3 et ai :

use Test::More;
use Test::Exception;
use Data::Dumper;

use Data::Tubes qw< pipeline summon >;

summon('+Plumbing::cache');
ok __PACKAGE__->can('cache'), "summoned cache";


done_testing();

