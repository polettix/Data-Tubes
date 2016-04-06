package Data::Tubes::Util;

# vim: ts=3 sts=3 sw=3 et ai :

use strict;
use warnings;
use Exporter 'import';
our $VERSION = '0.723';

use Log::Log4perl::Tiny qw< :easy :dead_if_first >;

our @EXPORT_OK = qw<
  args_array_with_options
  assert_all_different
  load_module
  load_sub
  metadata
  normalize_args
  normalize_filename
  resolve_module
  shorter_sub_names
  sprintffy
  test_all_equal
  traverse
  tube
  unzip
>;

sub _load_module {
   my $module = shift;
   (my $packfile = $module . '.pm') =~ s{::}{/}gmxs;
   require $packfile;
   return $module;
} ## end sub _load_module

sub args_array_with_options {
   my %defaults = %{pop @_};
   %defaults = (%defaults, %{pop @_})
     if @_ && (ref($_[-1]) eq 'HASH');
   return ([@_], \%defaults);
} ## end sub args_array_with_options

sub assert_all_different {
   my $keys = (@_ && ref($_[0])) ? $_[0] : \@_;
   my %flag_for;
   for my $key (@$keys) {
      die {message => $key} if $flag_for{$key}++;
   }
   return 1;
} ## end sub assert_all_different

sub load_module {
   my $module = resolve_module(@_);
   (my $packfile = $module . '.pm') =~ s{::}{/}gmxs;
   require $packfile;
   return $module;
} ## end sub load_module

sub load_sub {
   my ($locator, $prefix) = @_;
   my ($module, $sub) =
     ref($locator) ? @$locator : $locator =~ m{\A(.*)::(\w+)\z}mxs;
   $module = resolve_module($module, $prefix);

   # optimistic first
   return $module->can($sub) // _load_module($module)->can($sub);
} ## end sub load_sub

sub metadata {
   my $input = shift;
   my %args  = normalize_args(
      @_,
      {
         chunks_separator    => ' ',
         key_value_separator => '=',
         default_key         => '',
      }
   );

   # split data into chunks, un-escape on the fly
   my $separator = $args{chunks_separator};
   my $qs        = quotemeta($separator);
   my $regexp    = qr/((?:\\.|[^\\$qs])+)(?:$qs+)?/;
   my @chunks    = map { s{\\(.)}{$1}g; $_ } $input =~ m{$regexp}gc;

   # ensure we consumed the whole $input
   die {message =>
        "invalid metadata (separator: '$separator', input: [$input])\n"
     }
     if pos($input) < length($input);

   $separator = $args{key_value_separator};
   return {
      map {
         my ($k, $v) = _split_pair($_, $separator);
         defined($v) ? ($k, $v) : ($args{default_key} => $k);
      } @chunks
   };
} ## end sub metadata

sub normalize_args {
   my $defaults = pop;
   my %retval =
     (%$defaults, ((@_ && ref($_[0]) eq 'HASH') ? %{$_[0]} : @_));
   return %retval if wantarray();
   return \%retval;
} ## end sub normalize_args

sub normalize_filename {
   my ($filename, $default_handle) = @_;
   return $filename       if ref($filename) eq 'GLOB';
   return $filename       if ref($filename) eq 'SCALAR';
   return $default_handle if $filename eq '-';
   return $filename       if $filename =~ s{\Afile:}{}mxs;
   if (my ($handlename) = $filename =~ m{\Ahandle:(?:std)?(.*)\z}imxs) {
      $handlename = lc $handlename;
      return \*STDOUT if $handlename eq 'out';
      return \*STDIN  if $handlename eq 'err';
      return \*STDERR if $handlename eq 'in';
      LOGDIE "normalize_filename: invalid filename '$filename', "
        . "use 'file:$filename' if name is correct";
   } ## end if (my ($handlename) =...)
   return $filename;
} ## end sub normalize_filename

sub resolve_module {
   my ($module, $prefix) = @_;

   my ($first) = substr $module, 0, 1;
   return substr $module, 1 if $first eq '!';

   $prefix //= 'Data::Tubes::Plugin';
   if ($first eq '+') {
      $module = substr $module, 1;
   }
   elsif ($module =~ m{::}mxs) {
      $prefix = undef;
   }
   return $module unless defined $prefix;
   return $prefix . '::' . $module;
} ## end sub resolve_module

sub shorter_sub_names {
   my $stash = shift(@_) . '::';

   no strict 'refs';

   # isolate all subs
   my %sub_for =
     map { *{$stash . $_}{CODE} ? ($_ => *{$stash . $_}{CODE}) : (); }
     keys %$stash;

   # iterate through inputs, work only on isolated subs and don't
   # consider shortened ones
   for my $prefix (@_) {
      while (my ($name, $sub) = each %sub_for) {
         next if index($name, $prefix) < 0;
         my $shortname = substr $name, length($prefix);
         *{$stash . $shortname} = $sub;
      }
   } ## end for my $prefix (@_)

   return;
} ## end sub shorter_sub_names

sub _split_pair {
   my ($input, $separator) = @_;
   my $qs     = quotemeta($separator);
   my $regexp = qr{(?mxs:\A((?:\\.|[^\\$qs])+)$qs(.*)\z)};
   my ($first, $second) = $input =~ m{$regexp};
   ($first, $second) = ($input, undef) unless defined($first);
   $first =~ s{\\(.)}{$1}gmxs;    # unescape metadata
   return ($first, $second);
} ## end sub _split_pair

sub sprintffy {
   my ($template, $substitutions) = @_;
   my $len = length $template;
   pos($template) = 0;            # initialize
   my @chunks;
 QUEST:
   while (pos($template) < $len) {
      $template =~ m{\G (.*?) (% | \z)}mxscg;
      my ($plain, $term) = ($1, $2);
      my $pos = pos($template);
      push @chunks, $plain;
      last unless $term;          # got a percent, have to continue
    CANDIDATE:
      for my $candidate ([qr{%} => '%'], @$substitutions) {
         my ($regex, $value) = @$candidate;
         $template =~ m{\G$regex}cg or next CANDIDATE;
         $value = $value->() if ref($value) eq 'CODE';
         push @chunks, $value;
         next QUEST;
      } ## end CANDIDATE: for my $candidate ([qr{%}...])

      # didn't find a matchin thing... time to complain
      die {message => "invalid sprintffy template '$template'"};
   } ## end QUEST: while (pos($template) < $len)
   return join '', @chunks;
} ## end sub sprintffy

sub test_all_equal {
   my $reference = shift;
   for my $candidate (@_) {
      return if $candidate ne $reference;
   }
   return 1;
} ## end sub test_all_equal

sub traverse {
   my ($data, @keys) = @_;
   for my $key (@keys) {
      if (ref($data) eq 'HASH') {
         $data = $data->{$key};
      }
      elsif (ref($data) eq 'ARRAY') {
         $data = $data->[$key];
      }
      else {
         return undef;
      }
      return undef unless defined $data;
   } ## end for my $key (@keys)
   return $data;
} ## end sub traverse

sub tube {
   my $locator = shift;
   return load_sub($locator)->(@_);
} ## end sub tube

sub unzip {
   my $items = (@_ && ref($_[0])) ? $_[0] : \@_;
   my $n_items = scalar @$items;
   my (@evens, @odds);
   my $i = 0;
   while ($i < $n_items) {
      push @evens, $items->[$i++];
      push @odds, $items->[$i++] if $i < $n_items;
   }
   return (\@evens, \@odds);
} ## end sub unzip

1;
