package Text::Tubes::Plugin::Parser;
use strict;
use warnings;
use English qw< -no_match_vars >;

use Log::Log4perl::Tiny qw< :easy :dead_if_first >;

use Text::Tubes::Util
  qw< assert_all_different metadata normalize_args test_all_equal unzip >;
my %global_defaults = (
   input  => 'raw',
   output => 'structured',
);

sub parse_by_format {
   my %args = normalize_args(@_, {%global_defaults,});
   my $format = $args{format};
   LOGDIE "parser of type 'format' needs a definition"
     unless defined $format;

   my @items = split m{(\W+)}, $format;
   return parse_single(key => $items[0]) if @items == 1;

   my ($keys, $separators) = unzip(\@items);

   # all keys MUST be different, otherwise some fields are just trumping
   # on each other
   eval { assert_all_different($keys); }
     or LOGDIE "'format' parser [$format] "
     . "has duplicate key $EVAL_ERROR->{message}";

   # a simple split will do if all separators are the same
   return parse_by_split(%args, keys => $keys,
      separator => $separators->[0])
     if test_all_equal(@$separators);

   return parse_by_regexes(%args, keys => $keys,
      separators => $separators);
} ## end sub parse_by_format

sub parse_by_regex {
   my %args = normalize_args(@_, {%global_defaults,});
   my $regex = $args{regex};
   LOGDIE "parse_by_regex needs a regex"
     unless defined $regex;

   $regex = qr{$regex};
   my $input      = $args{input};
   my $has_input  = defined($input) && length($input);
   my $output     = $args{output};
   my $has_output = defined($output) && length($output);
   return sub {
      my $record = shift;
      ($has_input ? $record->{$input} : $record) =~ m{$regex}
        or die {message => "invalid record"};
      my $retval = {%+};
      return {record => $retval} unless $has_output;
      $record = {} unless $has_input;
      $record->{$output} = $retval;
      return {record => $record};
   };
} ## end sub parse_by_regex

sub parse_by_regexes {
   my %args = normalize_args(@_, {%global_defaults,});
   my $keys = $args{keys};
   LOGDIE "parse_by_regexes needs keys"
     unless defined $keys;
   my $separators = $args{separators};
   LOGDIE "parse_by_regexes needs separators"
     unless defined $separators;
   my $delta = scalar(@$keys) - scalar(@$separators);
   LOGDIE "parse_by_regexes 0 <= #keys - #separators <= 1"
     if ($delta < 0) || ($delta > 1);

   my @items;
   for my $i (0 .. $#$keys) {
      push @items, '(.*?)';                                     # keys
      push @items, '(?:' . quotemeta($separators->[$i]) . ')'
        if $i <= $#$separators;
   }

   # if not a separator, the last item becomes a catchall
   $items[-1] = '(.*)' if $delta > 0;

   # ready to generate the regexp. We bind the end to \z anyway because
   # the last element might be a separator
   my $format = join '', '(?:\\A', @items, '\\z)';
   my $regex = qr{$format};
   DEBUG "regex will be: $regex";

   # this sub will use the regexp above, do checking and return captured
   # values in a hash with @keys
   my $n_keys     = scalar @$keys;
   my $input      = $args{input};
   my $has_input  = defined($input) && length($input);
   my $output     = $args{output};
   my $has_output = defined($output) && length($output);
   return sub {
      my $record = shift;
      my @values = ($has_input ? $record->{$input} : $record) =~ m{$regex}
        or die {message => 'invalid record'};
      die      {message => "invalid record, wrong number of items"}
        if scalar(@values) != $n_keys;
      my %retval;
      @retval{@$keys} = @values;

      return {record => \%retval} unless $has_output;
      $record = {} unless $has_input;
      $record->{$output} = \%retval;
      return {record => $record};
   };
} ## end sub parse_by_regexes

sub parse_by_split {
   my %args = normalize_args(@_, {%global_defaults,});
   my $separator = $args{separator};
   LOGDIE "parse_by_split needs a separator"
     unless defined $separator;
   if (! ref $separator) {
      $separator = quotemeta($separator);
      $separator = qr{$separator};
   }

   my $keys       = $args{keys};
   my $n_keys     = defined($keys) ? scalar(@$keys) : 0;
   my $input      = $args{input};
   my $has_input  = defined($input) && length($input);
   my $output     = $args{output};
   my $has_output = defined($output) && length($output);

   return sub {
      my $record = shift;
      my $text = $has_input ? $record->{$input} : $record;

      my @values = split /$separator/, $text, $n_keys;
      die {message => "invalid record, wrong number of items"}
        if scalar(@values) != $n_keys;

      my %retval;
      @retval{@$keys} = @values;

      return {record => \%retval} unless $has_output;
      $record = {} unless $has_input;
      $record->{$output} = \%retval;
      return {record => $record};
     }
     if $n_keys;

   return sub {
      my $record = shift;
      my $text   = $has_input ? $record->{$input} : $record;
      my @retval = split /$separator/, $text;
      return {record => \@retval} unless $has_output;
      $record = {} unless $has_input;
      $record->{$output} = \@retval;
      return {record => $record};
   };

} ## end sub parse_by_split

sub parse_hashy {
   my %args = normalize_args(
      @_,
      {
         chunks_separator    => ' ',
         default_key         => '',
         key_value_separator => '=',
         %global_defaults,
      }
   );
   my %defaults   = %{$args{defaults} || {}};
   my $input      = $args{input};
   my $has_input  = defined($input) && length($input);
   my $output     = $args{output};
   my $has_output = defined($output) && length($output);
   return sub {
      my $record = shift;
      my $parsed =
        metadata(($has_input ? $record->{$input} : $record), \%args);
      my $retval = {%defaults, %$parsed};
      return {record => $retval} unless $has_output;
      $record = {} unless $has_input;
      $record->{$output} = $retval;
      return {record => $record};
   };
} ## end sub parse_hashy

sub parse_single {
   my %args = normalize_args(
      @_,
      {
         key => 'key',
         %global_defaults,
      }
   );
   my $key        = $args{key};
   my $has_key    = defined($key) && length($key);
   my $input      = $args{input};
   my $has_input  = defined($input) && length($input);
   my $output     = $args{output};
   my $has_output = defined($output) && length($output);
   return sub {
      my $record = shift;
      my $parsed = $has_input ? $record->{$input} : $record;
      my $retval = $has_key ? {$key => $parsed} : $parsed;
      return {record => $retval} unless $has_output;
      $record = {} unless $has_input;
      $record->{$output} = $retval;
      return {record => $record};
     }
} ## end sub parse_single

1;
