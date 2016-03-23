package Data::Tubes::Plugin::Renderer;
use strict;
use warnings;
use English qw< -no_match_vars >;

use Log::Log4perl::Tiny qw< :easy :dead_if_first >;

use Data::Tubes::Util qw< normalize_args >;
my %global_defaults = (
   input  => 'structured',
   output => 'rendered',
);

sub render_with_template_perlish {
   my %args = normalize_args(
      @_,
      {
         %global_defaults,
         start     => '[%',
         stop      => '%]',
         variables => {},
         name => 'render with Template::Perlish',
      }
   );
   my $name = $args{name};
   LOGDIE "$name: template is mandatory"
      unless defined $args{template};

   require Template::Perlish;
   my $tp = Template::Perlish->new(
      map { $_ => $args{$_} }
      grep { defined $args{$_} } qw< start stop variables >
   );
   my $template = $tp->compile($args{template});

   my $input      = $args{input};
   my $has_input  = defined($input) && length($input);
   my $output     = $args{output};
   my $has_output = defined($output) && length($output);
   return sub {
      my $record    = shift;
      my $variables = $has_input ? $record->{$input} : $record;
      my $retval    = $tp->evaluate($template, $variables);
      return {record => $retval} unless $has_output;
      $record = {} unless $has_input;
      $record->{$output} = $retval;
      return {record => $record};
   };
} ## end sub render_template_perlish