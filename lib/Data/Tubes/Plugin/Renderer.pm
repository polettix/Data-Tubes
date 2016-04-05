package Data::Tubes::Plugin::Renderer;
use strict;
use warnings;
use English qw< -no_match_vars >;
our $VERSION = '0.723';

use Log::Log4perl::Tiny qw< :easy :dead_if_first >;

use Data::Tubes::Util qw< normalize_args shorter_sub_names >;
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
   my $output     = $args{output};
   return sub {
      my $record    = shift;
      $record->{$output} = $tp->evaluate($template, $record->{$input});
      return $record;
   };
} ## end sub render_template_perlish

shorter_sub_names(__PACKAGE__, 'render_');

1;
