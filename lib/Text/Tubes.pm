package Text::Tubes;

use strict;
use warnings;
use English qw< -no_match_vars >;
{ our $VERSION = '0.01'; }
use Exporter qw< import >;

use Log::Log4perl::Tiny qw< :easy :dead_if_first LOGLEVEL >;
use Text::Tubes::Tube;

our @EXPORT_OK = (
   qw<
     loglevel
     summon
     tube
     >
);
our %EXPORT_TAGS = (all => \@EXPORT_OK,);

sub loglevel { LOGLEVEL(@_) }

sub summon {                       # sort-of import
   my ($cpack) = caller(0);
   for my $r (@_) {
      my $hash;
      if (ref($r) ne 'HASH') {
         my ($rpack, $rname) = $r=~ m{\A(.*)::(\w+)\z}mxs;
         $hash = {$rpack => $rname};
      }
      else {
         $hash = {%$r};
      }
      while (my ($pack, $names) = each %$hash) {
         $pack = 'Text::Tubes::Plugin::' . substr($pack, 1)
            if substr($pack, 0, 1) eq '+';
         (my $fpack = "$pack.pm") =~ s{::}{/}gmxs;
         require $fpack;
         for my $name (ref($names) ? @$names : $names) {
            no strict 'refs';
            *{$cpack . '::' . $name} = \&{$pack . '::' . $name};
         }
      }
   } ## end for my $r (@_)
} ## end sub summon

sub tube {
   my ($name, $operation) = @_;
   return Text::Tubes::Tube(
      name      => $name,
      operation => $operation,
   );
} ## end sub tube

1;
__END__
