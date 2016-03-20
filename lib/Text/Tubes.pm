package Text::Tubes;

use strict;
use warnings;
use English qw< -no_match_vars >;
{ our $VERSION = '0.01'; }
use Exporter qw< import >;
use Data::Dumper;
use Scalar::Util qw< blessed >;

use Log::Log4perl::Tiny qw< :easy :dead_if_first LOGLEVEL >;
use Text::Tubes::Tube;

our @EXPORT_OK = (
   qw<
     loglevel
     sequence
     tube
     >
);
our %EXPORT_TAGS = (all => \@EXPORT_OK,);

sub loglevel { LOGLEVEL(@_) }

sub sequence {
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
               my $pos = $#stack;

               my $frame = $stack[$pos];
               my $record;
               if (exists $frame->{record}) {
                  $record = delete $frame->{record};
               }
               elsif (exists $frame->{records}) {
                  $record = shift @{$frame->{records}};
               }
               elsif (exists $frame->{iterator}) {
                  $record = $frame->{iterator}->();
               }

               if (!defined $record) {    # no more at this level...
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

               push @stack, $o; # and go to next level
            } ## end STEP: while (@stack)

            return; # end of output
         },
      };
   };
} ## end sub sequence

sub tube {
   my ($name, $operation) = @_;
   return Text::Tubes::Tube(
      name      => $name,
      operation => $operation,
   );
} ## end sub tube

1;
__END__
