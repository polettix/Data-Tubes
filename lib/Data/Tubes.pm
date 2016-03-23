package Data::Tubes;

use strict;
use warnings;
use English qw< -no_match_vars >;
{ our $VERSION = '0.01'; }
use Exporter qw< import >;

use Log::Log4perl::Tiny qw< :easy :dead_if_first LOGLEVEL >;

our @EXPORT_OK = (
   qw<
     drain
     summon
     >
);
our %EXPORT_TAGS = (all => \@EXPORT_OK,);

sub drain {
   my $tube = shift;
   my $outcome = $tube->(@_);
   my $iterator = $outcome->{iterator} // return;
   while (my @items = $iterator->()) {}
}

sub summon {    # sort-of import
   my ($cpack) = caller(0);
   for my $r (@_) {
      my @parts;
      if (ref($r) eq 'ARRAY') {
         @parts = $r;
      }
      elsif (ref($r) eq 'HASH') {
         while (my ($pack, $names) = each %$r) {
            my @names = ref($names) ? @$names : $names;
            push @parts, [$pack, @names];
         }
      }
      else {
         my ($pack, $name) = $r =~ m{\A(.*)::(\w+)\z}mxs;
         @parts = [$pack, $name];
      }
      for my $part (@parts) {
         my ($pack, @names) = @$part;
         $pack = 'Data::Tubes::Plugin::' . substr($pack, 1)
         if substr($pack, 0, 1) eq '+';
         (my $fpack = "$pack.pm") =~ s{::}{/}gmxs;
         require $fpack;
         for my $name (@names) {
            my $sub = $pack->can($name)
            or LOGDIE "package '$pack' has no '$name' inside";
            no strict 'refs';
            *{$cpack . '::' . $name} = $sub;
         } ## end for my $name (@names)
      } ## end for my $r (map { my $i ...})
   }
} ## end sub summon

1;
__END__
