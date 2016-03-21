package Text::Tubes::Plugin::Reader;
use strict;
use warnings;
use English qw< -no_match_vars >;
use Log::Log4perl::Tiny qw< :easy :dead_if_first >;

use Text::Tubes::Util qw< normalize_args >;
my %global_defaults = (
   input  => 'source',
   output => 'raw',
);

sub read_by_line {
   return read_by_separator(normalize_args(@_, {}), separator => "\n");
}

sub read_by_paragraph {
   return read_by_separator(normalize_args(@_, {}), separator => '');
}

sub read_by_record_reader {
   my %args = normalize_args(
      @_,
      {
         %global_defaults,
         emit_eof => 0,
      },
   );
   my $emit_eof      = $args{emit_eof};
   my $input         = $args{input};
   my $has_input     = defined($input) && length($input);
   my $output        = $args{output};
   my $record_reader = $args{record_reader};
   return sub {
      my $record = shift;
      my $source = $has_input ? $record->{$input} : $record;
      my $fh     = $source->{fh};

      return {
         iterator => sub {
            my $read = $record_reader->($fh);
            my $retval = {%$record, $output => $read};
            return $retval if defined $read;
            if ($emit_eof) {
               $emit_eof = 0;
               return $retval;
            }
            return;
         },
      };
   };
} ## end sub by_record_reader

sub read_by_regex {
   ...;
}

sub read_by_separator {
   my %args      = normalize_args(@_, {chomp => 1});
   my $separator = $args{separator};
   my $chomp     = $args{chomp};
   return read_by_record_reader(
      %args,
      record_reader => sub {
         my $fh = shift;
         local $INPUT_RECORD_SEPARATOR = $separator;
         my $retval = <$fh>;
         chomp($retval) if defined($retval) && $chomp;
         return $retval;
      },
   );
} ## end sub by_separator

sub files {
   my %args = normalize_args(
      @_,
      {
         binmode => ':encoding(UTF-8)',
         output  => 'source',
         files   => [],
      }
   );

   # valid "output" sub-fields must be defined and at least one char long
   # otherwise output will be ignored
   my $binmode    = $args{binmode};
   my $output     = $args{output};
   my $has_output = defined($output) && length($output);

   return sub {
      my @files = grep { defined }
        (@{$args{files}}, ((@_ && ref($_[0]) eq 'ARRAY') ? @{$_[0]} : @_));
      return {
         iterator => sub {
            return unless @files;

            my $file = shift @files;
            my $record;
            if (ref($file) eq 'GLOB') {
               my $is_stdin = fileno($file) == fileno(\*STDIN);
               my $name = $is_stdin ? 'STDIN' : "$file";
               $record = {
                  fh    => $file,
                  input => $file,
                  type  => 'handle',
                  name  => "handle\:$name",
               };
            } ## end if (ref($file) eq 'GLOB')
            else {
               open my $fh, '<', $file
                 or die "open('$file'): $OS_ERROR";
               binmode $fh, $binmode;
               my $type = (ref($file) eq 'SCALAR') ? 'scalar' : 'file';
               $record = {
                  fh    => $fh,
                  input => $file,
                  type  => $type,
                  name  => "$type\:$file",
               };
            } ## end else [ if (ref($file) eq 'GLOB')]

            DEBUG "files: using $record->{name}";

            # put as a sub-field if so requested (which is what happens by
            # default)
            $record = {$output => $record} if $has_output;

            return $record;
         },
      };
   };
} ## end sub files

1;
