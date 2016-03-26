package Data::Tubes;

# vim: ts=3 sts=3 sw=3 et ai :

use strict;
use warnings;
use English qw< -no_match_vars >;
{ our $VERSION = '0.01'; }
use Exporter qw< import >;

use Log::Log4perl::Tiny qw< :easy :dead_if_first LOGLEVEL >;
use Data::Tubes::Util qw<
  args_array_with_options
  load_sub
  normalize_args
  resolve_module
>;

our @EXPORT_OK = (
   qw<
     drain
     pipeline
     summon
     tube
     >
);
our %EXPORT_TAGS = (all => \@EXPORT_OK,);

sub drain {
   my $tube = shift;
   my ($type, $iterator) = $tube->(@_) or return;
   return unless defined($iterator) && ($type eq 'iterator');
   while (my @items = $iterator->()) { }
} ## end sub drain

sub pipeline {
   my ($tubes, $args) = args_array_with_options(@_, {name => 'sequence'});

   my $tap = delete $args->{tap};
   $tap = sub {
      my $iterator = shift;
      while (my @items = $iterator->()) { }
      return;
     }
     if defined($tap) && ($tap eq 'sink');

   if ((!defined($tap)) && (defined($args->{pump}))) {
      my $pump = delete $args->{pump};
      $tap = sub {
         my $iterator = shift;
         while (my ($record) = $iterator->()) {
            $pump->($record);
         }
         return;
        }
   } ## end if ((!defined($tap)) &&...)
   LOGDIE 'invalid tap or pump'
     if $tap && ref($tap) ne 'CODE';

   my $sequence = tube('+Plumbing::sequence', %$args, tubes => $tubes);
   return $sequence unless $tap;

   return sub {
      my (undef, $iterator) = $sequence->(@_) or return;
      return $tap->($iterator);
   };
} ## end sub pipeline

sub summon {    # sort-of import
   my ($imports, $args) = args_array_with_options(
      @_,
      {
         prefix  => 'Data::Tubes::Plugin',
         package => (caller(0))[0],
      }
   );
   my $prefix = $args->{prefix};
   my $cpack = $args->{package};

   for my $r (@_) {
      my @parts;
      if (ref($r) eq 'ARRAY') {
         @parts = $r;
      }
      else {
         my ($pack, $name) = $r =~ m{\A(.*)::(\w+)\z}mxs;
         @parts = [$pack, $name];
      }
      for my $part (@parts) {
         my ($pack, @names) = @$part;
         $pack = resolve_module($pack, $prefix);
         (my $fpack = "$pack.pm") =~ s{::}{/}gmxs;
         require $fpack;
         for my $name (@names) {
            my $sub = $pack->can($name)
              or LOGDIE "package '$pack' has no '$name' inside";
            no strict 'refs';
            *{$cpack . '::' . $name} = $sub;
         } ## end for my $name (@names)
      } ## end for my $part (@parts)
   } ## end for my $r (@_)
} ## end sub summon

sub tube {
   my $locator = shift;
   return load_sub($locator)->(@_);
} ## end sub tube

1;
__END__
