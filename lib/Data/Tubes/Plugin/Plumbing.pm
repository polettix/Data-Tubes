package Data::Tubes::Plugin::Plumbing;

# vim: ts=3 sts=3 sw=3 et ai :

use strict;
use warnings;
use English qw< -no_match_vars >;
use Data::Dumper;
use Scalar::Util qw< blessed >;
our $VERSION = '0.723';

use Log::Log4perl::Tiny
  qw< :easy :dead_if_first get_logger LOGLEVEL LEVELID_FOR >;
use Data::Tubes::Util
  qw< args_array_with_options normalize_args traverse >;
use Data::Tubes::Plugin::Util qw< identify log_helper tubify >;

sub alternatives {
   my ($tubes, $args) =
     args_array_with_options(@_, {name => 'alternatives'});
   identify($args);
   my $name = $args->{name};

   my @tubes = tubify(@$tubes);

   return sub {
      my $record = shift;
      for my $tube (@tubes) {
         if (my @retval = $tube->($record)) {
            return @retval;
         }
      }
      return;
   };
} ## end sub alternatives

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

   my $handler_for = {%{$args{handlers} || {}}};    # our cache
   my $factory = $args{factory};
   if (!defined($factory)) {
      $factory = sub {
         my ($key, $record) = @_;
         die {
            message => "$name: unhandled selection key '$key'",
            record  => $record,
         };
      };
   } ## end if (!defined($factory))
   LOGDIE "$name: required factory or handlers"
     unless defined $factory;

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

sub fallback {

   # we lose syntax sugar but allow for Try::Tiny to remain optional
   eval { require Try::Tiny; }
     or LOGCONFESS 'Data::Tubes::Plugin::Plumbing::fallback '
     . 'needs Try::Tiny, please install';

   my ($tubes, $args) = args_array_with_options(@_, {name => 'fallback'});
   identify($args);
   my $name = $args->{name};

   my @tubes = tubify(@$tubes);

   my $catch = $args->{catch};
   return sub {
      my $record = shift;
      for my $tube (@tubes) {
         my (@retval, $do_fallback);
         Try::Tiny::try(
            sub {
               @retval = $tube->($record);
            },
            Try::Tiny::catch(
               sub {
                  $catch->($_, $record) if $catch;
                  $do_fallback = 1;
               }
            )
         );
         return @retval unless $do_fallback;
      } ## end for my $tube (@tubes)
      return;
   };
} ## end sub fallback

sub logger {
   my %args = normalize_args(@_, {name => 'log pipe', loglevel => $INFO});
   identify(\%args);
   my $loglevel = LEVELID_FOR($args{loglevel});
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

sub pipeline {
   my ($tubes, $args) = args_array_with_options(@_, {name => 'pipeline'});
   return sequence(%$args, tubes => $tubes);
}

sub sequence {
   my %args = normalize_args(@_, {name => 'sequence'});
   identify(\%args);

   # cope with an empty list of tubes - equivalent to an "id" function but
   # always returning an iterator for consistency
   my $tubes = $args{tubes} || [];
   return sub {
      my @record = shift;
      return (
         iterator => sub {
            return unless @record;
            return shift @record;
         }
      );
     }
     unless @$tubes;

   # auto-generate tubes if you get definitions
   my @tubes = tubify(@$tubes);

   my $logger = log_helper(\%args);
   my $name   = $args{name};
   return sub {
      my $record = shift;
      $logger->($record, \%args) if $logger;

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
      return (iterator => $iterator);
   };
} ## end sub sequence

1;
