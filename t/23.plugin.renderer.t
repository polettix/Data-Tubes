use strict;
use Test::More;
use Data::Dumper;

use Data::Tubes qw< summon >;

my @functions = qw<
  render_with_template_perlish
>;
summon(['+Renderer', @functions]);
ok __PACKAGE__->can($_), "summoned $_" for @functions;

my $structured = {
   what   => 'ever',
   you    => 'like',
   please => 'do',
};
my $target_string = "Have you ever felt like you have to do something?\n";

{
   my $template = <<'END';
Have you [% what %] felt [% you %] you have to [% please %] something?
END
   my $rend = render_with_template_perlish(template => $template);
   my $outcome = $rend->({structured => $structured});
   is ref($outcome), 'HASH', 'outcome is a hash';
   ok exists($outcome->{record}), 'outcome is a record';
   my $record = $outcome->{record};
   is ref($record), 'HASH', 'record is a hash';
   is_deeply $record,
     {structured => $structured, rendered => $target_string},
     'rendering of the string';
}

{
   my $template = <<'END';
Have you {{ what }} felt {{ you }} you have to {{ please }} {{ new }}?
END
   my $rend = render_with_template_perlish(
      template  => $template,
      input     => 'foo',
      output    => 'bar',
      start     => '{{',
      stop      => '}}',
      variables => {
         what => 'XXXX',         # overridden by data in record
         new  => 'something',    # preserved
      },
   );
   my $outcome = $rend->({foo => $structured});
   is ref($outcome), 'HASH', 'outcome is a hash';
   ok exists($outcome->{record}), 'outcome is a record';
   my $record = $outcome->{record};
   is ref($record), 'HASH', 'record is a hash';
   is_deeply $record,
     {foo => $structured, bar => $target_string},
     'rendering of the string';
}

done_testing();
