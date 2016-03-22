package Text::Tubes::Plugin::Reader;
use strict;
use warnings;
use English qw< -no_match_vars >;
use Log::Log4perl::Tiny qw< :easy :dead_if_first >;

use Text::Tubes::Util qw< normalize_args >;
use Text::Tubes::Plugin::Util qw< identify >;
my %global_defaults = (
   input  => 'source',
   output => 'raw',
);

sub read_by_line {
   return read_by_separator(
      normalize_args(
         @_,
         {
            name           => 'read_by_line',
            identification => {caller => [caller(0)]},
         }
      ),
      separator => "\n",
   );
} ## end sub read_by_line

sub read_by_paragraph {
   return read_by_separator(
      normalize_args(
         @_,
         {
            name           => 'read_by_paragraph',
            identification => {caller => [caller(0)]},
         }
      ),
      separator => '',
   );
} ## end sub read_by_paragraph

sub read_by_record_reader {
   my %args = normalize_args(
      @_,
      {
         %global_defaults,
         emit_eof       => 0,
         name           => 'read_by_record_reader',
         identification => {caller => [caller(0)]},
      },
   );
   identify(\%args, $args{identification});
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
} ## end sub read_by_record_reader

sub read_by_regex {
   ...;
}

sub read_by_separator {
   my %args = normalize_args(
      @_,
      {
         name           => 'read_by_separator',
         chomp          => 1,
         identification => {caller => [caller(0)]},
      }
   );
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
} ## end sub read_by_separator

sub open_file {
   my %args = normalize_args(
      @_,
      {
         binmode => ':encoding(UTF-8)',
         output  => 'source',
         name    => 'open file',
      }
   );
   identify(\%args, $args{identification});

   # valid "output" sub-fields must be defined and at least one char long
   # otherwise output will be ignored
   my $binmode   = $args{binmode};
   my $output    = $args{output};
   my $input     = $args{input};
   my $has_input = defined($input) && length($input);

   return sub {
      my ($record, $file) =
        $has_input ? ($_[0], $_[0]{$input}) : ({}, $_[0]);

      if (ref($file) eq 'GLOB') {
         my $is_stdin = fileno($file) == fileno(\*STDIN);
         my $name = $is_stdin ? 'STDIN' : "$file";
         $record->{$output} = {
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
         $record->{$output} = {
            fh    => $fh,
            input => $file,
            type  => $type,
            name  => "$type\:$file",
         };
      } ## end else [ if (ref($file) eq 'GLOB')]

      return {record => $record};
   };
} ## end sub open_file

sub files {
   my %args = normalize_args(
      @_,
      {
         binmode => ':encoding(UTF-8)',
         output  => 'source',
         files   => [],
         name    => 'files',
      }
   );
   identify(\%args, $args{identification});

   use Text::Tubes::Plugin::Plumbing;
   my $ai = Text::Tubes::Plugin::Plumbing::array_iterator(
      %args,
      array => ($args{files} || []),
   );
   return Text::Tubes::Plugin::Plumbing::sequence(
      tubes => [
         $ai,
         open_file(%args),
      ]
   );
} ## end sub files

1;
