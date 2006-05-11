package RT::Interface::Email::Filter::TakeAction;

use warnings;
use strict;

=head2 my commands

Queue: <name> Set new queue for the ticket
Status: <status> Set new status, one of new, open, stalled,
resolved, rejected or deleted
Owner: <username> Set new owner using the given username
FinalPriority: <#> Set new final priority to the given value (1-99)
Priority: <#> Set new priority to the given value (1-99)
Subject: <string> Set new subject to the given string
Due: <new timestamp> Set new due date/timestamp, or 0 to disable.
+AddCc: <address> Add new Cc watcher using the email address
+DelCc: <address> Remove email address as Cc watcher
+AddAdminCc: <address> Add new AdminCc watcher using the email address
+DelAdminCc: <address> Remove email address as AdminCc watcher
+AddRequestor: <address> Add new requestor using the email address
+DelRequestor: <address> Remove email address as requestor
Starts: <new timestamp>
Started: <new timestamp>
TimeWorked: <minutes> Replace the tickets 'timeworked' value.
TimeEstimated: <minutes>
TimeLeft: <minutes>
DependsOn:
DependedOnBy:
RefersTo:
ReferredToBy:
HasMember:
MemberOf:
CustomField-C<CFName>:
CF-C<CFName>:

=cut

sub GetCurrentUser {
    my %args = (
        Message       => undef,
        RawMessageRef => undef,
        CurrentUser   => undef,
        AuthLevel     => undef,
        Action        => undef,
        Ticket        => undef,
        Queue         => undef,
        @_
    );

    warn "We're in it";

    # If the user isn't asking for a comment or a correspond,
    # bail out
    if ( $args{'Action'} !~ /^(?:comment|correspond)$/i ) {
        warn "bad action";
        return ( $args{'CurrentUser'}, $args{'AuthLevel'} );
    }

    my @content;
    warn "after the action";
    my @parts = $args{'Message'}->parts_DFS;
    foreach my $part (@parts) {

        #if it looks like it has pseudoheaders, that's our content
        if ( $part->stringify_body =~ /^(?:\S+):/m ) {
            warn "Got it";
            @content = $part->bodyhandle->as_lines();

            last;
        }

    }
    use YAML;
    warn YAML::Dump( \@content );
    warn "walking lines";
    my @items;
    foreach my $line (@content) {
        warn "My line is $line";
        last if ( $line !~ /^(?:(\S+)\s*?:\s*?(.*)\s*?|)$/ );
        push( @items, $1 => $2 );
    }
    my %cmds;
    while ( my $key = lc shift @items ) {
        my $value = shift @items;
        if ( $key =~ /^(?:Add|Del)/i ) {
            push @{ $cmds{$key} }, $val;
        } else {
            $cmds{$key} = $val;

        }
    }

    use YAML;
    warn YAML::Dump( \@items );
    my %results;

    my $ticket_as_user = RT::Ticket->new( $args{'CurrentUser'} );

    if ( $args{'Ticket'}->id ) {
        $ticket_as_user->Load( $args{'Ticket'}->id );

        foreach my $attribute (
            qw(Queue Status Priority FinalPriority
            TimeWorked TimeLeft TimeEstimated Subject )
            ) {
            next
                unless ( defined $cmds{ lc $attribute }
                and
                ( $ticket_as_user->$attribute() ne $cmds{ lc $attribute } ) );

            _SetAttribute(
                $ticket_as_user,        $attribute,
                $cmds{ lc $attribute }, \%results
            );
        }

        foreach my $attribute (qw(Due Starts Started Resolved Told)) {
            next unless ( $cmds{ lc $attribute } );
            my $date = RT::Date->new( $args{'CurrentUser'} );
            $date->Set(
                Format => 'unknown',
                value  => $cmds{ lc $attribute }
            );
            _SetAttribute( $ticket_as_user, $attribute, $date->ISO,
                \%results );
            $results{ lc $attribute }->{value} = $cmds{ lc $attribute };
        }

        foreach my $base_attribute (qw(Requestor Cc AdminCc)) {
            foreach my $attribute ( $base_attribute, $base_attribute . "s" ) {
                if ( my $delete = $cmds{ lc "del" . $attribute } ) {
                    foreach my $email (@$delete) {
                        _SetWatcherAttribute( $ticket_as_user, "DelWatcher",
                            "del" . $attribute,
                            $base_attribute, $email );
                    }
                    if ( my $add = $cmds{ lc "add" . $attribute } ) {
                        foreach my $email (@$add) {
                            _SetWatcherAttribute( $ticket_as_user,
                                "AddWatcher", "add" . $attribute,
                                $base_attribute, $email );
                        }
                    }
                }
            }
        }
        for (
            qw(MemberOf Parents Members Children
            HasMember RefersTo ReferredToBy
            DependsOn DependedOnBy)
            ) {

        }

        my $queue = RT::Queue->new( $args{'CurrentUser'} );
        if ( $cmds{'queue'} ) {
            $queue->Load( $cmds{'queue'} );
        }

        if ( !$queue->id ) {
            $queue->Load( $args{'Queue'}->id );
        }

        my $custom_fields = $queue->TicketCustomFields;

        while ( my $cf = $custom_fields->Next ) {
            next unless ( defined $cmds{ lc $cf->Name } );
            my ( $val, $msg ) = $ticket_as_user->AddCustomFieldValue(
                Field => $cf->id,
                Value => $cmds{ lc $cf->Name }
            );
            $results{ $cf->Name } = {
                value   => $cmds{ lc $cf->Name },
                result  => $val,
                message => $msg
            };
        }

    } else {

        my %create_args = ();

        # Canonicalize links
        # Canonicalize custom fields
        # Canonicalize watchers

        $ticket_as_user->Create(%create_args);

        # If we don't already have a ticket, we're going to create a new
        # ticket

    }
    warn YAML::Dump(\%results);
    return ( $args{'CurrentUser'}, $args{'AuthLevel'} );
}

sub _SetAttribute {
    my $ticket    = shift;
    my $attribute = shift;
    my $value     = shift;
    my $results   = shift;
    my $setter    = "Set$attribute";
    my ( $val, $msg ) = $ticket->$setter($value);
    $results->{$attribute} = {
        value   => $value,
        result  => $val,
        message => $msg
    };

}
1;

sub _SetWatcherAttribute {
    my $ticket    = shift;
    my $method    = shift;
    my $attribute = shift;
    my $type      = shift;
    my $email     = shift;
    my $results   = shift;
    my ( $val, $msg ) = $ticket->DelWatcher(
        Type  => $type,
        Email => $email
    );

    $results->{$attribute} = {
        value   => $value,
        result  => $val,
        message => $msg
    };

}
