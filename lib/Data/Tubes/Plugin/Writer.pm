package Data::Tubes::Plugin::Writer;
use strict;
use warnings;
use English qw< -no_match_vars >;
use POSIX qw< strftime >;

use Log::Log4perl::Tiny qw< :easy :dead_if_first LOGLEVEL >;
use Template::Perlish;

use Data::Tubes::Util qw< normalize_args shorter_sub_names sprintffy >;
use Data::Tubes::Plugin::Util qw< identify log_helper >;
use Data::Tubes::Plugin::Plumbing;
my %global_defaults = (input => 'rendered',);

sub _filenames_generator {
   my $template = shift;

   my $n             = 0; # counter, used in closures inside $substitutions
   my $substitutions = [
      [qr{(\d*)[din]} => sub { return sprintf "%${1}d",  $n; }],
      [qr{Y}          => sub { return strftime('%Y',     localtime()); }],
      [qr{m}          => sub { return strftime('%m',     localtime()); }],
      [qr{d}          => sub { return strftime('%d',     localtime()); }],
      [qr{H}          => sub { return strftime('%H',     localtime()); }],
      [qr{M}          => sub { return strftime('%M',     localtime()); }],
      [qr{S}          => sub { return strftime('%S',     localtime()); }],
      [qr{z}          => sub { return strftime('%z',     localtime()); }],
      [qr{D}          => sub { return strftime('%Y%m%d', localtime()); }],
      [qr{T} => sub { return strftime('%H%M%S%z',        localtime()); }],
      [qr{t} => sub { return strftime('%Y%m%dT%H%M%S%z', localtime()); }],
   ];

   # see if the template depends on the counter
   my $expanded = sprintffy($template, $substitutions);
   return sub {
      my $retval = sprintffy($template, $substitutions);
      ++$n;
      return $retval;
     }
     if ($expanded ne $template);    # it does!

   # then, by default, revert to poor's man expansion of name...
   return sub {
      my $retval = $n ? "${template}_$n" : $template;
      ++$n;
      return $retval;
   };
} ## end sub _filenames_generator

sub dispatch_to_files {
   my %args = normalize_args(
      @_,
      {
         %global_defaults,
         name    => 'write dispatcher',
         binmode => ':encoding(UTF-8)'
      }
   );
   identify(\%args);
   my $name = delete $args{name};    # so that it can be overridden

   my $factory = delete $args{filename_factory};
   if (!defined($factory) && defined($args{filename_template})) {
      my $tp = Template::Perlish->new(%{$args{template_perlish} || {}});
      my $template = $tp->compile($args{filename_template});
      $factory = sub {
         my ($key, $record) = @_;
         return $tp->evaluate($template, {key => $key, record => $record});
      };
   } ## end if (!defined($factory)...)

   $args{factory} //= sub {
      my $filename = $factory->(@_);
      return write_to_files(%args, filename => $filename);
   };

   return Data::Tubes::Plugin::Plumbing::dispatch(%args);
} ## end sub dispatch_to_files

sub write_to_files {
   my %args = normalize_args(
      @_,
      {
         %global_defaults,
         name    => 'write to file',
         binmode => ':encoding(UTF-8)'
      }
   );
   identify(\%args);
   my $name = $args{name};
   LOGDIE "$name: need a filename" unless defined $args{filename};
   LOGDIE "$name: need an input"   unless defined $args{input};

   my $factory = $args{filename};
   $factory = _filenames_generator($factory)
     unless ref($factory) eq 'CODE';
   require Data::Tubes::Util::Output;
   my $output_handler = Data::Tubes::Util::Output->new(
      output => $factory,
      map { ($_ => $args{$_}) }
        grep { exists $args{$_} } qw< binmode footer header policy >
   );

   my $input   = $args{input};
   return sub {
      my $record = shift;
      $output_handler->print($record->{$input});
      return $record;    # relaunch for further processing
   };
} ## end sub write_to_files

sub write_to_handle {
   my %args = normalize_args(
      @_,
      {
         %global_defaults,
         name    => 'write to handle',
         binmode => ':encoding(UTF-8)'
      }
   );
   identify(\%args);
   my $name = $args{name};
   LOGDIE "$name: need a handle" unless defined $args{handle};
   LOGDIE "$name: need an input" unless defined $args{input};

   my $fh = $args{handle};
   if (!ref($fh)) {
      $fh =
          (grep { lc($fh) eq $_ } qw< - stdout out >) ? \*STDOUT
        : ($fh =~ m{\A (?: std ) err \z}mxs) ? \*STDERR
        :   LOGDIE "$name: cannot use handle $fh";
   } ## end if (!ref($fh))

   binmode $fh, $args{binmode} if $args{binmode};

   my $input = $args{input};
   return sub {
      my $record = shift;
      print {$fh} $record->{$input};
      return $record;    # relaunch for further processing
   };
} ## end sub write_to_handle

shorter_sub_names(__PACKAGE__, 'write_');

1;
