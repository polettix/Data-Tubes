package Text::Tubes::Plugin::Util;
use strict;
use warnings;
use English qw< -no_match_vars >;

use Template::Perlish;
use Log::Log4perl::Tiny qw< :easy :dead_if_first get_logger >;

use Exporter qw< import >;
our @EXPORT_OK = qw< identify logger read_file >;

sub identify {
   my ($args, $opts) = @_;
   $args = {} unless defined $args;
   $opts = {} unless defined $opts;

   my $name = $args->{name};
   $name = '*unknown*' unless defined $name;

   my $level = $opts->{level};
   $level = 1 unless defined $level;
   my @caller_fields = qw<
     package
     filename
     line
     subroutine
     hasargs
     wantarray
     evaltext
     is_require
     hints
     bitmask
     hintsh
   >;
   my %caller;
   @caller{@caller_fields} = caller($level);

   my $message = $opts->{message};
   $message = 'building [% name %] as [% subroutine %]'
     unless defined $message;

   my $tp = Template::Perlish->new(%{$opts->{tp_opts} || {}});
   $message = $tp->process(
      $message,
      {
         %caller,
         name => $name,
         args => $args,
         opts => $opts,
      }
   );

   my $loglevel = $args->{loglevel};
   $loglevel = 'DEBUG' unless defined $loglevel;
   get_logger->log($loglevel, $message);

   return;
} ## end sub identify

sub logger {
   my ($args) = @_;
   return unless $args->{logger};

   my $opts = $args->{logger};
   return $opts if ref($opts) eq 'CODE';

   # generate one
   my $name = $args->{name};
   $name = '*unknown*' unless defined $name;

   my $message = $opts->{message};
   $message = '==> [% name %]' unless defined $message;

   my $tp = Template::Perlish->new(%{$opts->{tp_opts} || {}});
   $message = $tp->compile($message);

   my $logger = get_logger();
   my $loglevel = $args->{loglevel};
   $loglevel = 'DEBUG' unless defined $loglevel;

   # resolve $loglevel into numeric loglevel
   my $previous = $logger->level();
   $logger->level($loglevel);
   $loglevel = $logger->level();
   $logger->level($previous);

   return sub {
      my $level = $logger->level();
      return if $level < $loglevel;
      my $record = shift;
      my $rendered = $tp->evaluate($message, {record => $record});
      $logger->log($loglevel, $rendered);
   };
}

sub read_file {
   my %args = normalize_args(
      @_,
      {
         binmode => ':encoding(UTF-8)',
      }
   );
   open my $fh, '<', $args{filename}
     or LOGDIE "open('$args{filename}'): $OS_ERROR";
   binmode $fh, $args{binmode} if defined $args{binmode};
   local $INPUT_RECORD_SEPARATOR;
   return <$fh>;
} ## end sub read_file

1;