package Data::Tubes::Plugin::Util;

# vim: ts=3 sts=3 sw=3 et ai :

use strict;
use warnings;
use English qw< -no_match_vars >;
use Data::Dumper;
our $VERSION = '0.725003';

use Template::Perlish;
use Log::Log4perl::Tiny qw< :easy :dead_if_first get_logger >;
use Data::Tubes::Util qw< normalize_args tube >;

use Exporter qw< import >;
our @EXPORT_OK = qw< identify log_helper read_file tubify >;

sub identify {
   my ($args, $opts) = @_;
   $args //= {};
   $opts //= $args->{identification} // {};

   my $name = $args->{name};
   $name = '*unknown*' unless defined $name;

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

   if (exists $opts->{caller}) {
      @caller{@caller_fields} = @{$opts->{caller}};
   }
   else {
      my $level = $opts->{level};
      $level = 1 unless defined $level;
      @caller{@caller_fields} = caller($level);
   }

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

   my $loglevel = $opts->{loglevel};
   $loglevel = $DEBUG unless defined $loglevel;
   get_logger->log($loglevel, $message);

   return;
} ## end sub identify

sub log_helper {
   my ($args, $opts) = @_;
   $opts //= $args->{logger};
   return unless $opts;
   return $opts if ref($opts) eq 'CODE';

   # generate one
   my $name = $args->{name};
   $name = '*unknown*' unless defined $name;

   my $message = $opts->{message};
   $message = '==> [% args.name %]' unless defined $message;

   my $tp = Template::Perlish->new(%{$opts->{tp_opts} || {}});
   $message = $tp->compile($message);

   my $logger   = get_logger();
   my $loglevel = $opts->{loglevel};
   $loglevel = $DEBUG unless defined $loglevel;

   return sub {
      my $level = $logger->level();
      return if $level < $loglevel;
      my $record = shift;
      my $rendered =
        $tp->evaluate($message,
         {record => $record, args => $args, opts => $opts});
      $logger->log($loglevel, $rendered);
   };
} ## end sub log_helper

sub read_file {
   my %args = normalize_args(
      @_,
      [
         {binmode => ':encoding(UTF-8)'},
         'filename',    # default key for "straight" unnamed parameter
      ]
   );
   defined $args{filename}
     or LOGDIE 'read_file(): undefined filename';
   open my $fh, '<', $args{filename}
     or LOGDIE "read_file(): open('$args{filename}'): $OS_ERROR";
   if (defined $args{binmode}) {
      binmode $fh, $args{binmode}
        or LOGDIE "read_file(): binmode()"
        . " for $args{filename} failed: $OS_ERROR";
   }
   local $INPUT_RECORD_SEPARATOR;
   return <$fh>;
} ## end sub read_file

sub tubify {
   map {
      my $ref = ref $_;
      ($ref eq 'CODE')
        ? $_
        : tube(($ref eq 'ARRAY') ? @$_ : $_)
   } @_;
} ## end sub tubify

1;
