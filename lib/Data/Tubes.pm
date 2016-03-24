package Data::Tubes;

# vim: ts=3 sts=3 sw=3 et ai :

use strict;
use warnings;
use English qw< -no_match_vars >;
{ our $VERSION = '0.01'; }
use Exporter qw< import >;

use Log::Log4perl::Tiny qw< :easy :dead_if_first LOGLEVEL >;
use Data::Tubes::Util qw< load_sub normalize_args >;

our @EXPORT_OK = (
   qw<
     drain
     summon
     tub
     tuba
     tube
     >
);
our %EXPORT_TAGS = (all => \@EXPORT_OK,);

sub drain {
   my $tube     = shift;
   my @outcome  = $tube->(@_) or return;
   return if @outcome == 1;
   return if $outcome[0] eq 'records';
   my $iterator = $outcome[1];
   while (my @items = $iterator->()) { }
} ## end sub drain

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
      } ## end elsif (ref($r) eq 'HASH')
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
      } ## end for my $part (@parts)
   } ## end for my $r (@_)
} ## end sub summon

sub tub(&) { return tube(shift) }

sub tube {
   my $sub = shift;

   return load_sub($sub)->(@_) unless ref($sub) eq 'CODE';

   # optional arguments handling
   my $n = scalar @_;
   LOGDIE 'tub(): wrong number of arguments' if ($n % 2) && ($n != 1);
   my %args = normalize_args(
      (
           ($n != 1)              ? @_
         : (ref($_[0]) eq 'HASH') ? %{$_[0]}
         :                          @{$_[0]}
      ),
      {
         as => 'record',
      }
   );

   my $type = $args{as};
   $type = undef if ($type // '') eq 'record';
   return sub {
      my $outcome = $sub->(@_);
      return $outcome unless $type;
      return ($type => $outcome);
   };
} ## end sub tube

1;
__END__
