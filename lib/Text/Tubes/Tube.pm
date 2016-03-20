package Text::Tubes::Tube;

use strict;
use warnings;
{ our $VERSION = '0.01'; }

use Mo qw< default required >;

my $counter = 0;
has name => (
   is      => 'rw',
   default => sub { return 'tube-' . (++$counter) },
);

has operation => (
   is       => 'rw',
   required => 1,
);

sub operate {
   my $self = shift;
   return $self->operation()->(@_);
}

1;
__END__

