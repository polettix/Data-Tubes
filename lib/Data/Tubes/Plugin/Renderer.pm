package Data::Tubes::Plugin::Renderer;
use strict;
use warnings;
use English qw< -no_match_vars >;
our $VERSION = '0.727';

use Log::Log4perl::Tiny qw< :easy :dead_if_first >;

use Data::Tubes::Util qw< normalize_args shorter_sub_names >;
use Data::Tubes::Plugin::Util qw< read_file >;
my %global_defaults = (
   input  => 'structured',
   output => 'rendered',
);

sub _resolve_template {
   my $args = shift;

   my $ref = ref($args->{template});
   my $template =
       (!$ref || $ref eq 'HASH') ? $args->{template}
     : ($ref eq 'CODE')  ? $args->{template}->($args)
     : ($ref eq 'ARRAY') ? read_file(@{$args->{template}})
     :                     LOGDIE "invalid template of type $ref";
   LOGDIE 'invalid input template' unless defined $template;

   return $template if ref($template) eq 'HASH';
   return $args->{template_perlish}->compile($template);
} ## end sub _resolve_template

sub _create_tp {
   my $args = shift;
   require Template::Perlish;
   return Template::Perlish->new(
      map { $_ => $args->{$_} }
      grep { defined $args->{$_} } qw< start stop variables >
   );
} ## end sub _create_tp

sub render_with_template_perlish {
   my %args = normalize_args(
      @_,
      [
         {
            %global_defaults,
            start     => '[%',
            stop      => '%]',
            variables => {},
            name      => 'render with Template::Perlish',
         },
         'template'
      ]
   );
   my $name = $args{name};

   my $tp = $args{template_perlish} ||= _create_tp(\%args);
   my $template = _resolve_template(\%args);

   my $input  = $args{input};
   my $output = $args{output};
   return sub {
      my $record = shift;
      $record->{$output} = $tp->evaluate($template, $record->{$input});
      return $record;
   };
} ## end sub render_with_template_perlish

shorter_sub_names(__PACKAGE__, 'render_');

1;
