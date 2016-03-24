package Data::Tubes::Plugin::Plumbing;

# vim: ts=3 sts=3 sw=3 et ai :

use strict;
use warnings;
use English qw< -no_match_vars >;
use Data::Dumper;
use Scalar::Util qw< blessed >;

use Log::Log4perl::Tiny qw< :easy :dead_if_first get_logger LOGLEVEL >;
use Data::Tubes qw< tube >;
use Data::Tubes::Util
  qw< normalize_args traverse args_array_with_options >;
use Data::Tubes::Plugin::Util qw< identify log_helper >;

sub dispatch {
   my %args = normalize_args(@_,
      {default => undef, name => 'dispatch', loglevel => $INFO});
   identify(\%args);
   my $name = $args{name};

   my $selector = $args{selector};
   if (!defined($selector) && defined($args{key})) {
      my @key = ref($args{key}) ? @{$args{key}} : ($args{key});
      $selector = sub { return traverse($_[0], @key); };
   }
   LOGDIE "$name: required dispatch key or selector"
     unless defined $selector;

   my $handler_for = {};               # our cache
   my $factory     = $args{factory};
   if (!defined($factory) && defined($args{handlers})) {
      $handler_for = $args{handlers};
      $factory     = sub {
         my ($key, $record) = @_;
         die {
            message => "$name: unhandled selection key '$key'",
            record  => $record,
         };
      };
   } ## end if (!defined($factory)...)

   my $default = $args{default};
   return sub {
      my $record = shift;

      # get a key into the cache
      my $key = $selector->($record) // $default;
      die {
         message => "$name: selector key is undefined",
         record  => $record,
        }
        unless defined $key;

      # register a new handler... or die!
      $handler_for->{$key} = $factory->($key, $record)
        unless exists $handler_for->{$key};

      return $handler_for->{$key}->($record);
   };
} ## end sub dispatch

sub logger {
   my %args = normalize_args(@_, {name => 'log pipe', loglevel => $INFO});
   identify(\%args);
   my $loglevel = $args{loglevel};
   my $mangler  = $args{target};
   if (!defined $mangler) {
      $mangler = sub { return shift; }
   }
   elsif (ref($mangler) ne 'CODE') {
      my @keys = ref($mangler) ? @$mangler : ($mangler);
      $mangler = sub {
         my $record = shift;
         return traverse($record, @keys);
      };
   } ## end elsif (ref($mangler) ne 'CODE')
   my $logger = get_logger();
   return sub {
      my $record = shift;
      $logger->log($loglevel, $mangler->($record));
      return $record;
   };
} ## end sub logger

sub sequence {
   my ($tubes, $args) = args_array_with_options(@_, {name => 'sequence'});
   identify($args);

   # cope with empty list of tubes
   return sub { return {skip => 1} }
     unless @$tubes;

   # auto-generate tubes if you get definitions
   my @tubes = map {
      my $ref = ref $_;
      ($ref eq 'CODE')
        ? $_
        : tube(($ref eq 'ARRAY') ? @$_ : $_)
   } @$tubes;

   my $tap = $args->{tap};
   $tap = sub {
      my $iterator = shift;
      while (my @items = $iterator->()) { }
      return;
     }
     if defined($tap) && ($tap eq 'sink');

   if ((!defined($tap)) && (defined($args->{pump}))) {
      my $pump = $args->{pump};
      $tap = sub {
         my $iterator = shift;
         while (my @items = $iterator->()) {
            $pump->($items[0]);
         }
         return;
        }
   } ## end if ((!defined($tap)) &&...)
   LOGDIE 'invalid tap or pump'
     if $tap && ref($tap) ne 'CODE';

   my $logger = log_helper($args);
   my $name   = $args->{name};
   return sub {
      my $record = shift;
      $logger->($record, $args) if $logger;

      my @stack = ({record => $record});
      my $iterator = sub {
       STEP:
         while (@stack) {
            my $pos = $#stack;

            my $f = $stack[$pos];
            my @record =
                exists($f->{record})   ? delete $f->{record}
              : exists($f->{iterator}) ? $f->{iterator}->()
              : @{$f->{records} || []} ? shift @{$f->{records}}
              :                          ();
            if (!@record) {    # no more at this level...
               my $n = @stack;
               TRACE "$name: level $n backtracking, no more records";
               pop @stack;
               next STEP;
            } ## end if (!@record)

            my $record = $record[0];
            return $record if @stack > @tubes;    # output cache

            # something must be done...
            my @outcome = $tubes[$pos]->($record)
              or next STEP;

            unshift @outcome, 'record' if @outcome == 1;
            push @stack, {@outcome};              # and go to next level
         } ## end STEP: while (@stack)

         return;    # end of output, empty list
      };
      return $tap->($iterator) if $tap;
      return (iterator => $iterator);
   };
} ## end sub sequence

sub unwrap {
   my %args = normalize_args(@_,
      {name => 'unwrap', missing_ok => 0, missing_is_skip => 0});
   identify(\%args);
   my $logger = log_helper(\%args);
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
      return $record->{$key} if exists($record->{$key});
      return if $missing_is_skip;
      return undef if $missing_ok;
      die {message => "$name: no '$key' in record", record => $record};
   };
} ## end sub unwrap

sub wrap {
   my %args = normalize_args(@_, {name => 'wrap'});
   identify(\%args);
   my $logger = log_helper(\%args);
   my $name   = $args{name};
   my $key    = $args{key};
   LOGDIE "$name needs a key" unless defined $key;
   return sub {
      my $record = shift;
      $logger->($record, \%args) if $logger;
      return {$key => $record};
   };
} ## end sub wrap

1;
