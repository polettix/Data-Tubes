package Text::Tubes::Plugin::Writer;
use strict;
use warnings;
use English qw< -no_match_vars >;
use POSIX qw< strftime >;

use Log::Log4perl::Tiny qw< :easy :dead_if_first LOGLEVEL >;
use Template::Perlish;

use Text::Tubes::Util qw< normalize_args sprintffy >;
use Text::Tubes::Plugin::Util qw< identify log_helper >;
use Text::Tubes::Plugin::Plumbing;
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
      return write_to_file(%args, filename => $filename);
   };

   return Text::Tubes::Plugin::Plumbing::dispatch(%args);
} ## end sub dispatch_to_files

sub write_to_file {
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

   my $filename = $args{filename};
   my $tr       = $args{records_threshold} // 0;
   my $tc       = $args{characters_threshold} // 0;
   if (ref($filename) ne 'CODE') {
      if ($tr || $tc) {
         $filename = _filenames_generator($filename);
      }
      else {    # only one single filename will be needed...
         my $name = $filename;
         $filename = sub { return $name };
      }
   } ## end if (ref($filename) ne ...)

   my $input   = $args{input};
   my $binmode = $args{binmode};
   my $records = 0;
   my $chars   = 0;
   my $fh;
   return sub {
      my $record = shift;

      # open filehandle if not already available
      if (!defined $fh) {
         my $fname = $filename->();
         open $fh, '>',
           $fname
           or die {
            message => "$name: open('$fname'): $OS_ERROR",
            record  => $record,
            input   => $input,
           };
         binmode $fh, $binmode if $binmode;
      } ## end if (!defined $fh)

      print {$fh} $record->{$input};

      # possibly get rid of current filehandle if thresholds are overcome
      if ($tr || $tc) {
         $records++;
         $chars += length($record->{$input});
         if (($tr && ($records >= $tr)) || ($tc && ($chars >= $tc))) {
            close $fh;
            $fh = undef;
         }
      } ## end if ($tr || $tc)

      return {record => $record};    # relaunch for further processing
   };
} ## end sub write_to_file

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
      return {record => $record};    # relaunch for further processing
   };
} ## end sub write_to_handle

1;
