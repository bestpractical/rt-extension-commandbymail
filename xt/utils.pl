#!/usr/bin/perl

use strict;
use warnings;


BEGIN {
### after:     push @INC, qw(@RT_LIB_PATH@);
    push @INC, qw(/opt/rt3/local/lib /opt/rt3/lib);
}

use RT;
RT::LoadConfig();

use IPC::Open2;

### after: our $mailgate = '@RT_BIN_PATH@/rt-mailgate';
our $mailgate = '/opt/rt3/bin/rt-mailgate';
die "Couldn't find mailgate ($mailgate) command" unless -f $mailgate;

$mailgate .= ' --debug';
$mailgate .= ' --url '. $RT::WebURL;


sub run_gate {
    my %args = (
        message => '',
        action => 'correspond',
        queue => 'General',
        @_
    );
    my $cmd = $mailgate 
              ." --queue '$args{'queue'}'"
              ." --action $args{'action'}"
              ." 2>&1";

    DBIx::SearchBuilder::Record::Cachable->FlushCache;

    my ($child_out, $child_in);
    my $pid = open2($child_out, $child_in, $cmd);
    print $child_in $args{'message'};
    close $child_in;
    my $result = do { local $/; <$child_out> };
    return $result;
}

sub create_ticket_via_gate {
    my $message = shift;
    my $gate_result = run_gate( message => $message );
    $gate_result =~ /Ticket: (\d+)/;
    unless ( $1 ) {
        print STDERR "Couldn't find ticket id in text:\n$gate_result";
    }
    return $1;
}

1;

