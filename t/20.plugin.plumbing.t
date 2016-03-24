use strict;

# vim: ts=3 sts=3 sw=3 et ai :

use Test::More;
use Data::Dumper;

use Data::Tubes qw< summon tub tube >;

summon({'+Plumbing' => 'sequence'});
ok __PACKAGE__->can('sequence'), 'summoned sequence';

{
   my $sequence = sequence(\&first, \&second);
   my $output = $sequence->({});
   ok exists($output->{iterator}), 'sequence returned an iterator';

   my $iterator = $output->{iterator};
   is ref($iterator), 'CODE', 'iterator is a code reference';

   my $record = $iterator->();
   is_deeply $record, {first => 'hey', second => 'you'},
     'output record from sequence';

   my @rest = $iterator->();
   ok !@rest, 'nothing more comes out of the iterator';
}

{
   my $sequence = sequence([qw< !main::factory foo >], \&second, \&third);
   my $output = $sequence->({});
   ok exists($output->{iterator}), 'sequence returned an iterator';

   my $iterator = $output->{iterator};
   is ref($iterator), 'CODE', 'iterator is a code reference';

   my $record = $iterator->();
   is_deeply $record, {first => 'hey', second => 'you', third => 'some'},
     'output record from sequence';

   my @rest = $iterator->();
   is scalar(@rest), 1, 'one more comes out of the iterator';
   $record = shift @rest;
   is_deeply $record, {first => 'hey', second => 'you', third => 'thing'},
     'output record from sequence';

   @rest = $iterator->();
   ok !@rest, 'nothing more comes out of the iterator';
}

{
   my $pt1 = tub { return shift };
   my $pt2 = tube sub {
      my @items = @_;
      return sub { return unless @items; return shift @items; };
   }, as => 'iterator';
   my $pt3 = tube sub { return [@_] }, as => 'records';
   my $sequence =
     sequence('!main::factory', \&second, $pt1, $pt2, $pt3, \&iter_third);
   my $output = $sequence->({});
   ok exists($output->{iterator}), 'sequence returned an iterator';

   my $iterator = $output->{iterator};
   is ref($iterator), 'CODE', 'iterator is a code reference';

   my $record = $iterator->();
   is_deeply $record, {first => 'hey', second => 'you', third => 2},
     'output record from sequence';

   my @rest = $iterator->();
   is scalar(@rest), 1, 'one more comes out of the iterator';
   $record = shift @rest;
   is_deeply $record, {first => 'hey', second => 'you', third => 1},
     'output record from sequence';

   @rest = $iterator->();
   ok !@rest, 'nothing more comes out of the iterator';
}

sub first {
   my $record = shift;
   $record->{first} = 'hey';
   return {record => $record};
}

sub factory {
   return \&first;
}

sub second {
   my $record = shift;
   $record->{second} = 'you';
   return {record => $record};
}

sub third {
   my $record = shift;
   return {records =>
        [{%$record, third => 'some'}, {%$record, third => 'thing'},],
   };
} ## end sub third

sub iter_third {
   my $record  = shift;
   my $counter = 2;
   return {
      iterator => sub {
         return unless $counter;
         return {%$record, third => $counter--};
        }
   };
} ## end sub iter_third

sub fourth {
   my $record = shift;
   return $record;
}

done_testing();
