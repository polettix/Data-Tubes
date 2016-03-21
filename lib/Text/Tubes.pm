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
     summon
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

sub summon {                       # sort-of import
   my ($caller_package) = caller(0);
   for my $r (@_) {
      my $requested = (substr($r, 0, 1) eq '+')
         ? ('Text::Tubes::Plugin::' . substr($r, 1))
         : $r;
      my ($rpack, $rname) = $requested =~ m{\A(.*)::(\w+)\z}mxs;
      (my $fpack = "$rpack.pm") =~ s{::}{/}gmxs;
      require $fpack;

      no strict 'refs';
      *{$caller_package . '::' . $rname} = \&{$requested};
   }
}

sub tube {
   my ($name, $operation) = @_;
   return Text::Tubes::Tube(
      name      => $name,
      operation => $operation,
   );
} ## end sub tube

1;
__END__
