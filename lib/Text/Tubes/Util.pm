package Text::Tubes::Util;
use strict;
use warnings;
use Exporter 'import';

use Log::Log4perl::Tiny qw< :easy :dead_if_first >;

our @EXPORT_OK = qw<
  assert_all_different
  metadata
  normalize_args
  test_all_equal
  unzip
>;

sub assert_all_different {
   my $keys = (@_ && ref($_[0])) ? $_[0] : \@_;
   my %flag_for;
   for my $key (@$keys) {
      die {message => $key} if $flag_for{$key}++;
   }
   return 1;
} ## end sub assert_all_different

sub metadata {
   my $input = shift;
   my %args  = normalize_args(
      @_,
      {
         chunks_separator    => ' ',
         key_value_separator => '=',
         default_key         => '',
      }
   );

   # split data into chunks, un-escape on the fly
   my $separator = $args{chunks_separator};
   my $qs        = quotemeta($separator);
   my $regexp    = qr/((?:\\.|[^\\$qs])+)(?:$qs+)?/;
   my @chunks    = map { s{\\(.)}{$1}g; $_ } $input =~ m{$regexp}gc;

   # ensure we consumed the whole $input
   die {message =>
        "invalid metadata (separator: '$separator', input: [$input])\n"
     }
     if pos($input) < length($input);

   $separator = $args{key_value_separator};
   return {
      map {
         my ($k, $v) = split_pair($_, $separator);
         defined($v) ? ($k, $v) : ($args{default_key} => $k);
      } @chunks
   };
} ## end sub metadata

sub normalize_args {
   my $defaults = pop;
   my %retval =
     (%$defaults, ((@_ && ref($_[0]) eq 'HASH') ? %{$_[0]} : @_));
   return %retval if wantarray();
   return \%retval;
} ## end sub normalize_args

sub split_pair {
   my ($input, $separator) = @_;
   my $qs     = quotemeta($separator);
   my $regexp = qr{(?mxs:\A((?:\\.|[^\\$qs])+)$qs(.*)\z)};
   my ($first, $second) = $input =~ m{$regexp};
   ($first, $second) = ($input, undef) unless defined($first);
   $first =~ s{\\(.)}{$1}gmxs;    # unescape metadata
   return ($first, $second);
} ## end sub split_pair

sub test_all_equal {
   my $reference = shift;
   for my $candidate (@_) {
      return if $candidate ne $reference;
   }
   return 1;
} ## end sub test_all_equal

sub unzip {
   my $items = (@_ && ref($_[0])) ? $_[0] : \@_;
   my $n_items = scalar @$items;
   my (@evens, @odds);
   my $i = 0;
   while ($i < $n_items) {
      push @evens, $items->[$i++];
      push @odds, $items->[$i++] if $i < $n_items;
   }
   return (\@evens, \@odds);
} ## end sub unzip

1;
