package Text::Tubes::Plugin::Util;
use strict;
use warnings;
use English qw< -no_match_vars >;

use Log::Log4perl::Tiny qw< :easy :dead_if_first >;

sub read_file {
   my %args = normalize_args(
      @_,
      {
         binmode => ':encoding(UTF-8)',
      }
   );
   open my $fh, '<', $args{filename}
      or LOGDIE "open('$args{filename}'): $OS_ERROR";
   binmode $fh, $args{binmode} if defined $args{binmode};
   local $INPUT_RECORD_SEPARATOR;
   return <$fh>;
} ## end sub read_file

1;
