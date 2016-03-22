package Text::Tubes::Plugin::Plumbing;
use strict;
use warnings;
use English qw< -no_match_vars >;
use Data::Dumper;
use Scalar::Util qw< blessed >;

use Log::Log4perl::Tiny qw< :easy :dead_if_first get_logger LOGLEVEL >;
use Text::Tubes::Tube;
use Text::Tubes::Util qw< normalize_args traverse >;
use Text::Tubes::Plugin::Util qw< identify log_helper >;

sub logger {
   my %args = normalize_args(@_, {name => 'log pipe', loglevel => $INFO});
   identify(\%args);
   my $loglevel = $args{loglevel};
   my $mangler = $args{target};
   if (! defined $mangler) {
      $mangler = sub { return shift; }
   }
   elsif (ref($mangler) ne 'CODE') {
      my @keys = ref($mangler) ? @$mangler : ($mangler);
      $mangler = sub {
         my $record = shift;
         return traverse($record, @keys);
      };
   }
   my $logger = get_logger();
   return sub {
      my $record = shift;
      $logger->log($loglevel, $mangler->($record));
      return {record => $record};
   };
}

sub sequence {
   my %args = normalize_args(@_, {name => 'sequence'});
   identify(\%args);
   my $logger = log_helper($args{logger}, \%args);
   my $name = $args{name};

   my @tubes = @{$args{tubes}};

   return sub {
      my $record = shift;
      $logger->($record, \%args) if $logger;

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
                  my $n = @stack;
                  TRACE "$name: level $n backtracking, no more records";
                  pop @stack;
                  next STEP;
               }
               return $record if @stack > @tubes;    # output cache

               TRACE sub {
                  local $Data::Dumper::Indent = 1;
                  Dumper('record: ', $record);
               };

               # something must be done...
               my $o = $tubes[$pos]->($record);
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
   my $logger = log_helper($args{logger}, \%args);
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
   my $logger = log_helper($args{logger}, \%args);
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
   my $logger = log_helper($args{logger}, \%args);
   my $name   = $args{name};
   my $key    = $args{key};
   LOGDIE "$name needs a key" unless defined $key;
   return sub {
      my $record = shift;
      $logger->($record, \%args) if $logger;
      return {record => {$key => $record}};
   };
} ## end sub wrap

1;
