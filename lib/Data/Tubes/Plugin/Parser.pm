package Data::Tubes::Plugin::Parser;
use strict;
use warnings;
use English qw< -no_match_vars >;
use Data::Dumper;
our $VERSION = '0.727001';

use Log::Log4perl::Tiny qw< :easy :dead_if_first >;

use Data::Tubes::Util qw<
  assert_all_different
  generalized_hashy
  metadata
  normalize_args
  shorter_sub_names
  test_all_equal
  unzip
>;
use Data::Tubes::Plugin::Util qw< identify >;
my %global_defaults = (
   input  => 'raw',
   output => 'structured',
);

sub parse_by_format {
   my %args = normalize_args(@_,
      [{%global_defaults, name => 'parse by format'}, 'format']);
   identify(\%args);

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
   return parse_by_split(
      %args,
      keys      => $keys,
      separator => $separators->[0]
   ) if test_all_equal(@$separators);

   return parse_by_separators(
      %args,
      keys       => $keys,
      separators => $separators
   );
} ## end sub parse_by_format

sub parse_by_regex {
   my %args =
     normalize_args(@_,
      [{%global_defaults, name => 'parse by regex'}, 'regex']);
   identify(\%args);

   my $name  = $args{name};
   my $regex = $args{regex};
   LOGDIE "parse_by_regex needs a regex"
     unless defined $regex;

   $regex = qr{$regex};
   my $input  = $args{input};
   my $output = $args{output};
   return sub {
      my $record = shift;
      $record->{$input} =~ m{$regex}
        or die {
         message => "'$name': invalid record, regex is $regex",
         input   => $input,
         record  => $record,
        };
      my $retval = {%+};
      $record->{$output} = $retval;
      return $record;
   };
} ## end sub parse_by_regex

sub parse_by_separators {
   my %args = normalize_args(@_, {%global_defaults,});
   identify(\%args);

   my $keys = $args{keys};
   LOGDIE "parse_by_separators needs keys"
     unless defined $keys;
   my $separators = $args{separators};
   LOGDIE "parse_by_separators needs separators"
     unless defined $separators;
   my $delta = scalar(@$keys) - scalar(@$separators);
   LOGDIE "parse_by_separators 0 <= #keys - #separators <= 1"
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
   my $n_keys = scalar @$keys;
   my $name   = $args{name};
   my $input  = $args{input};
   my $output = $args{output};

   return sub {
      my $record = shift;
      my @values = $record->{$input} =~ m{$regex}
        or die {message => 'invalid record', record => $record};
      my $n_values = @values;
      die {
         message => "'$name': invalid record, expected $n_keys items, "
           . "got $n_values",
         record => $record
        }
        if $n_values != $n_keys;
      $record->{$output} = \my %retval;
      @retval{@$keys} = @values;
      return $record;
   };
} ## end sub parse_by_separators

sub parse_by_split {
   my %args =
     normalize_args(@_,
      [{%global_defaults, name => 'parse by split'}, 'separator']);
   identify(\%args);

   my $name      = $args{name};
   my $separator = $args{separator};
   LOGDIE "parse_by_split needs a separator"
     unless defined $separator;
   if (!ref $separator) {
      $separator = quotemeta($separator);
      $separator = qr{$separator};
   }

   my $keys          = $args{keys};
   my $n_keys        = defined($keys) ? scalar(@$keys) : 0;
   my $input         = $args{input};
   my $output        = $args{output};
   my $allow_missing = $args{allow_missing} || 0;

   return sub {
      my $record = shift;

      my @values = split /$separator/, $record->{$input}, $n_keys;
      my $n_values = @values;
      die {
         message => "'$name': invalid record, expected $n_keys items, "
           . "got $n_values",
         input  => $input,
         record => $record,
        }
        if $n_values + $allow_missing < $n_keys;

      $record->{$output} = \my %retval;
      @retval{@$keys} = @values;
      return $record;
     }
     if $n_keys;

   return sub {
      my $record = shift;
      my @retval = split /$separator/, $record->{$input};
      $record->{$output} = \@retval;
      return $record;
   };

} ## end sub parse_by_split

sub parse_ghashy {
   my %args = normalize_args(@_,
      {%global_defaults, default_key => '', name => 'parse ghashy'});
   identify(\%args);

   my %defaults = %{$args{defaults} || {}};
   my $input    = $args{input};
   my $output   = $args{output};

   # pre-compile capture thing from generalized_hashy
   $args{capture} = generalized_hashy(%args, text => undef)->{capture};

   return sub {
      my $record = shift;
      my $outcome = generalized_hashy(%args, text => $record->{$input});
      die {
         input   => $input,
         message => $outcome->{failure},
         outcome => $outcome,
         record  => $record,
        }
        unless exists $outcome->{hash};
      $record->{$output} = {%defaults, %{$outcome->{hash}}};
      return $record;
   };
} ## end sub parse_ghashy

sub parse_hashy {
   my %args = normalize_args(
      @_,
      {
         %global_defaults,
         chunks_separator    => ' ',
         default_key         => '',
         key_value_separator => '=',
         name                => 'parse hashy',
      }
   );
   identify(\%args);
   my %defaults = %{$args{defaults} || {}};
   my $input    = $args{input};
   my $output   = $args{output};
   return sub {
      my $record = shift;
      my $parsed = metadata($record->{$input}, %args);
      $record->{$output} = {%defaults, %$parsed};
      return $record;
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
   identify(\%args);
   my $key     = $args{key};
   my $has_key = defined($key) && length($key);
   my $input   = $args{input};
   my $output  = $args{output};
   return sub {
      my $record = shift;
      $record->{$output} =
        $has_key ? {$key => $record->{$input}} : $record->{$input};
      return $record;
     }
} ## end sub parse_single

shorter_sub_names(__PACKAGE__, 'parse_');

1;
