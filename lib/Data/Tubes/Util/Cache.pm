package Data::Tubes::Util::Cache;
use strict;
use warnings;
use English qw< -no_match_vars >;
use 5.010;
our $VERSION = '0.728';

use Log::Log4perl::Tiny qw< :easy :dead_if_first >;
use Mo qw< default >;
has cache => (default => sub { return {} });
has max_items => (default => 0);

sub get {
   my ($self, $key) = @_;
   my $cache = $self->cache();
   return unless exists $cache->{$key};
   return $cache->{$key};
} ## end sub get

sub set {
   my ($self, $key, $data) = @_;
   return $self->cache()->{$key} = $data;
}

sub purge {
   my $self  = shift;
   my $max   = $self->max_items() or return;
   my $cache = $self->cache();
   my $n     = scalar keys %$cache;
   delete $cache->{(keys %$cache)[0]} while $n-- > $max;
   return;
} ## end sub purge
