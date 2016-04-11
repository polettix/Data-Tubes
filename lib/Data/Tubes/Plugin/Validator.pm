package Data::Tubes::Plugin::Validator;
use strict;
use warnings;
use English qw< -no_match_vars >;
our $VERSION = '0.725002';

use Log::Log4perl::Tiny qw< :easy :dead_if_first >;

use Data::Tubes::Util qw< args_array_with_options shorter_sub_names >;
use Data::Tubes::Plugin::Util qw< identify >;
my %global_defaults = (input => 'structured',);

sub validate_accept {
   my ($validators, $args) = args_array_with_options(
      @_,
      {
         input => 'raw',
         name  => 'validate with acceptance regexp',
      }
   );
   identify($args);
   my $name   = $args->{name};
   my $input  = $args->{input};
   my $reject = $args->{reject};
   return sub {
      my $record = shift;
      my $target = defined($input) ? $record->{$input} : $record;
      for my $i (0 .. $#$validators) {
         my ($name, $validator) =
           (ref($validators->[$i]) eq 'ARRAY')
           ? @{$validators->[$i]}
           : ("validator-$i $validators->[$i]", $validators->[$i]);
         my $outcome =
           (ref($validator) eq 'CODE')
           ? $validator->($target)
           : ($target =~ m{$validator});
         $outcome = !$outcome if $reject;
         return unless $outcome;
      } ## end for my $i (0 .. $#$validators)
      return $record;
   };
} ## end sub validate_accept

sub validate_reject {
   my ($validators, $args) = args_array_with_options(
      @_,
      {
         input => 'raw',
         name  => 'validate with rejection regexp',
      }
   );
   $args->{reject} = 1;
   return validate_accept(@$validators, $args);
} ## end sub validate_reject

sub validate_reject_comment {
   my $args = normalize_args(@_,
      {name => 'validate reject comment line'});
   identify($args);
   return validate_reject(qr{(?mxs:\A \s* \#)}, $args);
}

sub validate_reject_comment_or_empty {
   my $args = normalize_args(@_,
      {name => 'validate reject comment or non-spaces-only line'});
   identify($args);
   return validate_reject(qr{(?mxs:\A \s* (?: \# | \z ))}, $args);
}

sub validate_reject_empty {
   my $args = normalize_args(@_,
      {name => 'validate reject empty (non-spaces only) string'});
   identify($args);
   return validate_accept(qr{\S}, $args);
}

sub validate_with_subs {
   my ($validators, $args) = args_array_with_options(
      @_,
      {
         %global_defaults,
         name           => 'validate with subs',
         output         => 'validation',
         keep_positives => 0,
         keep_empty     => 0,
         wrapper        => undef,
      }
   );
   identify($args);
   my $name = $args->{name};

   my $wrapper = $args->{wrapper};
   if ($wrapper && $wrapper eq 'try') {
      eval { require Try::Tiny; }
        or LOGCONFESS '+Validator::validate_with_subs '
        . 'needs Try::Tiny, please install';

      $wrapper = sub {
         my ($validator, @params) = @_;
         return Try::Tiny::try(
            sub { $validator->(@params); },
            Try::Tiny::catch(sub { return (0, $_); }),
         );
      };
   } ## end if ($wrapper && $wrapper...)

   my $input          = $args->{input};
   my $output         = $args->{output};
   my $keep_positives = $args->{keep_positives};
   my $keep_empty     = $args->{keep_empty};
   return sub {
      my $record = shift;
      my $target = defined($input) ? $record->{$input} : $record;
      my @outcomes;
      for my $i (0 .. $#$validators) {
         my ($name, $validator, @params) =
           (ref($validators->[$i]) eq 'ARRAY')
           ? @{$validators->[$i]}
           : ("validator-$i", $validators->[$i]);
         my @outcome =
             $wrapper
           ? $wrapper->($validator, $target, $record, $args, @params)
           : $validator->($target, $record, $args, @params);
         push @outcome, 0 unless @outcome;
         push @outcomes, [$name, @outcome]
           if !$outcome[0] || $keep_positives;
      } ## end for my $i (0 .. $#$validators)
      $record->{$output} = undef;
      $record->{$output} = \@outcomes if @outcomes || $keep_empty;
      return $record;
   };
} ## end sub validate_with_subs

shorter_sub_names(__PACKAGE__, 'validate_');

1;
