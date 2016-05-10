use strict;
use Test::More;
use Data::Dumper;

use Data::Tubes qw< pipeline >;

{
   my $tube = pipeline(
      sub {
         my $record = shift;
         $record->{first} = 1;
         return $record;
      },
      sub {
         my $record = shift;
         $record->{second} = 2;
         return $record;
      },
   );
   isa_ok $tube, 'CODE';

   my @outcome = $tube->({});
   is scalar(@outcome), 2, '2 items from tube invocation';
   is $outcome[0], 'iterator', 'result is an iterator';
   my $iterator = $outcome[1];

   my @items = $iterator->();
   is scalar(@items), 1, 'one item from the iterator';
   is_deeply $items[0], {first => 1, second => 2}, 'item from iterator';

   my @items = $iterator->();
   is scalar(@items), 0, 'no more items from the iterator';
}

{
   my $tube = pipeline(
      sub {
         my $record = shift;
         $record->{first} = 1;
         return $record;
      },
      sub {
         my $record = shift;
         $record->{second} = 2;
         return $record;
      },
      {tap => 'sink'},
   );
   isa_ok $tube, 'CODE';

   my @outcome = $tube->({});
   is scalar(@outcome), 0, 'no items from tube invocation with sink';
}

{
   my $tube = pipeline(
      sub {
         my $record = shift;
         $record->{first} = 1;
         return $record;
      },
      sub {
         my $record = shift;
         $record->{second} = 2;
         return $record;
      },
      {tap => 'bucket'},
   );
   isa_ok $tube, 'CODE';

   my @outcome = $tube->({});
   is scalar(@outcome), 1, '1 item from tube invocation with bucket';
   is_deeply $outcome[0], {first => 1, second => 2}, 'item from tube';
}

{
   my $tube = pipeline(
      sub {
         my $record = shift;
         $record->{first} = 1;
         return (records => [$record, {%$record}]);
      },
      sub {
         my $record = shift;
         $record->{second} = 2;
         return $record;
      },
      {tap => 'bucket'},
   );
   isa_ok $tube, 'CODE';

   my @outcome = $tube->({});
   is scalar(@outcome), 2, '2 items from tube invocation with bucket';
   is $outcome[0], 'records', 'sequence of records';
   is scalar(@{$outcome[1]}), 2, '2 items in sequence';
   is_deeply $outcome[1][0], {first => 1, second => 2}, 'item from tube';
   is_deeply $outcome[1][1], {first => 1, second => 2}, 'item from tube';
}

done_testing();
