use strict;
use warnings;

### after: use lib qw(@RT_LIB_PATH@);
use lib qw(/opt/rt4/local/lib /opt/rt4/lib);

package RT::Extension::CommandByMail::Test;
require RT::Test;
our @ISA = 'RT::Test';

sub import {
    my $class = shift;
    my %args  = @_;

    $args{'requires'} ||= [];
    if ( $args{'testing'} ) {
        unshift @{ $args{'requires'} }, 'RT::Extension::CommandByMail';
    } else {
        $args{'testing'} = 'RT::Extension::CommandByMail';
    }

    $class->SUPER::import( %args );
    $class->export_to_level(1);

    require RT::Extension::CommandByMail;
}

1;
