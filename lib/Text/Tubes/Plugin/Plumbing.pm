package Text::Tubes::Plugin::Plumbing;
use strict;
use warnings;
use English qw< -no_match_vars >;
use Data::Dumper;
use Scalar::Util qw< blessed >;

use Log::Log4perl::Tiny qw< :easy :dead_if_first get_logger >;
use Text::Tubes::Tube;
use Text::Tubes::Plugin::Util qw< identify logger >;

sub array_source {
   my %args = normalize_args(@_, {name => 'array source'});
   identify(\%args);
   my $logger = logger(\%args);
   my $array = $args{array} || [];
   my $i = 0;
   return sub {
      return if $i > $#$array;
      return {record => $array->[$i++]};
   };
}

sub iterator_source {
   my %args = normalize_args(@_, {name => 'iterator source'});
   identify(\%args);
   my $logger = logger(\%args);
   my $iterator = $args{array} || sub { return };
   return sub {
      my @items = $iterator->();
      return unless @items;
      return {record => $items[0]};
   };
}

sub sequence {
   my $args = (@_ && ref($_[0]) eq 'HASH') ? shift : {};
   my @tubes =
     map { blessed($_) ? $_ : Text::Tubes::Tube->new(operation => $_); }
     @_;
   return sub {
      my $record = shift;
      my @stack = ({record => $record});
      return {
         iterator => sub {
          STEP:
            while (@stack) {
               my $pos   = $#stack;
               my $frame = $stack[$pos];

               my ($has_record, $record);
               if (exists $frame->{record}) {
                  $record     = delete $frame->{record};
                  $has_record = 1;
               }
               elsif (exists $frame->{records}) {
                  $record = shift @{$frame->{records}}
                    if $has_record = @{$frame->{records}};
               }
               elsif (exists $frame->{iterator}) {
                  my @buffer = $frame->{iterator}->();
                  $record = shift @buffer
                    if $has_record = @buffer;
               }

               if (!$has_record) {    # no more at this level...
                  DEBUG 'no more records';
                  pop @stack;
                  next STEP;
               }
               return $record if @stack > @tubes;    # output cache

               TRACE sub {
                  local $Data::Dumper::Indent = 1;
                  Dumper('record: ', $record);
               };

               # something must be done...
               my $tube = $tubes[$pos];
               DEBUG 'calling', sub { $tube->name() };

               my $o = $tube->operate($record);
               TRACE sub {
                  local $Data::Dumper::Indent = 1;
                  Dumper('output: ', $o);
               };

               next STEP
                 if (!defined $o) || (exists $o->{skip});

               push @stack, $o;    # and go to next level
            } ## end STEP: while (@stack)

            return;                # end of output, empty list
         },
      };
   };
} ## end sub sequence

sub sink {
   my %args = normalize_args(@_, {name => 'sink'});
   identify(\%args);
   my $logger = logger(\%args);
   return sub {
      my $record = shift;
      $logger->($record, \%args) if $logger;
      return {skip => 1};
   };
} ## end sub sink

sub unwrap {
   my %args = normalize_args(@_,
      {name => 'unwrap', missing_ok => 0, missing_is_skip => 0});
   identify(\%args);

   my $logger = logger(\%args);
   my $name   = $args{name};
   my $key    = $args{key};
   LOGDIE "$name needs a key" unless defined $key;
   my $missing_ok      = $args{missing_ok};
   my $missing_is_skip = $args{missing_is_skip};
   return sub {
      my $record = shift;
      $logger->($record, \%args) if $logger;
      die {message => "$name: not a hash reference", record => $record}
        unless ref($record) eq 'HASH';
      return {record => $record->{$key}} if exists($record->{$key});
      return {skip   => 1}               if $missing_is_skip;
      return {record => undef}           if $missing_ok;
      die {message => "$name: no '$key' in record", record => $record};
   };
} ## end sub unwrap

sub wrap {
   my %args = normalize_args(@_, {name => 'wrap'});
   identify(\%args);
   my $logger = logger(\%args);
   my $key    = $args{key};
   LOGDIE "$name needs a key" unless defined $key;
   return sub {
      my $record = shift;
      $logger->($record, \%args) if $logger;
      return {record => {$key => $record}};
   };
} ## end sub wrap

1;
