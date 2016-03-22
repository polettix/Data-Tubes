package Text::Tubes::Plugin::Source;
use strict;
use warnings;
use English qw< -no_match_vars >;
use Log::Log4perl::Tiny qw< :easy :dead_if_first LOGLEVEL >;

use Text::Tubes::Util qw< normalize_args >;
use Text::Tubes::Plugin::Util qw< identify log_helper >;
my %global_defaults = (
   input  => 'source',
   output => 'raw',
);

sub iterate_array {
   my %args = normalize_args(@_, {name => 'array iterator'});
   identify(\%args);
   my $logger = log_helper(\%args);
   my $global_array = $args{array} || [];
   my $n_global = @$global_array;
   return sub {
      my $local_array = shift || [];
      $logger->($local_array, \%args) if $logger;
      my $n_local = @$local_array;
      my $i = 0;
      return { iterator => sub {
         return $global_array->[$i++] if $i < $n_global;
         return $local_array->[($i++) - $n_global]
            if $i < $n_global + $n_local;
         return;
      },};
   };
}

sub open_file {
   my %args = normalize_args(
      @_,
      {
         binmode => ':encoding(UTF-8)',
         output  => 'source',
         name    => 'open file',
      }
   );
   identify(\%args);

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

sub iterate_files {
   my %args = normalize_args(
      @_,
      {
         binmode => ':encoding(UTF-8)',
         output  => 'source',
         name    => 'files',
         files   => [],
         array_iterator => {},
         open_file => {},
         logger => {
            target => sub {
               my $record = shift;
               return 'reading from ' . $record->{source}{name},
            },
         },
      }
   );
   identify(\%args);

   use Text::Tubes::Plugin::Plumbing;
   return Text::Tubes::Plugin::Plumbing::sequence(
      tubes => [
         iterate_array(
            %{$args{array_iterator}},
            array => ($args{files} || []),
         ),
         open_file(%{$args{open_file}}),
         Text::Tubes::Plugin::Plumbing::logger(%{$args{logger}}),
      ]
   );
} ## end sub files

1;
