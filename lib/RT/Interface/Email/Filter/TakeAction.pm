package RT::Interface::Email::Filter::TakeAction;

use warnings;
use strict;

our @REGULAR_ATTRIBUTES = qw(Queue Status Priority FinalPriority
                             TimeWorked TimeLeft TimeEstimated Subject );
our @DATE_ATTRIBUTES    = qw(Due Starts Started Resolved Told);
our @LINK_ATTRIBUTES    = qw(MemberOf Parents Members Children
            HasMember RefersTo ReferredToBy DependsOn DependedOnBy);

=head2 my commands

Queue: <name> Set new queue for the ticket
Subject: <string> Set new subject to the given string
Status: <status> Set new status, one of new, open, stalled,
resolved, rejected or deleted
Owner: <username> Set new owner using the given username
Priority: <#> Set new priority to the given value (1-99)
FinalPriority: <#> Set new final priority to the given value (1-99)

+Requestor: <address> Set requestor(s) using the email address
+AddRequestor: <address> Add new requestor using the email address
+DelRequestor: <address> Remove email address as requestor
+Cc: <address> Set Cc watcher(s) using the email address
+AddCc: <address> Add new Cc watcher using the email address
+DelCc: <address> Remove email address as Cc watcher
+AdminCc: <address> Set AdminCc watcher(s) using the email address
+AddAdminCc: <address> Add new AdminCc watcher using the email address
+DelAdminCc: <address> Remove email address as AdminCc watcher

Due: <new timestamp> Set new due date/timestamp, or 0 to disable.
Starts: <new timestamp>
Started: <new timestamp>
TimeWorked: <minutes> Replace the tickets 'timeworked' value.
TimeEstimated: <minutes>
TimeLeft: <minutes>

+DependsOn:
+AddDependsOn:
+DelDependsOn
+DependedOnBy:
+RefersTo:
+ReferredToBy:
+HasMember:
+MemberOf:

CustomField.{C<CFName>}:
AddCustomField.{C<CFName>}:
DelCustomField.{C<CFName>}:
CF.{C<CFName>}:
AddCF.{C<CFName>}:
DelCF.{C<CFName>}:

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
        last if ( $line !~ /^(?:(\S+)\s*?:\s*?(.*)\s*?|)$/ );
        push( @items, $1 => $2 );
    }
    my %cmds;
    while ( my $key = _CanonicalizeCommand( lc shift @items ) ) {
        my $val = shift @items;
        # strip leading and trailing spaces
        $val =~ s/^\s+|\s+$//g;

        if ( exists $cmds{$key} ) {
            $cmds{$key} = [ $cmds{$key} ] unless ref $cmds{$key};
            push @{ $cmds{$key} }, $val;
        } else {
            $cmds{$key} = $val;
        }
    }
    warn YAML::Dump( { Commands => \%cmds } );

    my %results;

    my $ticket_as_user = RT::Ticket->new( $args{'CurrentUser'} );
    my $queue          = RT::Queue->new( $args{'CurrentUser'} );
    if ( $cmds{'queue'} ) {
        $queue->Load( $cmds{'queue'} );
    }

    if ( !$queue->id ) {
        $queue->Load( $args{'Queue'}->id );
    }

    # If we're updating.
    if ( $args{'Ticket'}->id ) {
        $ticket_as_user->Load( $args{'Ticket'}->id );

        foreach my $attribute (@REGULAR_ATTRIBUTES) {
            next unless ( defined $cmds{ lc $attribute }
                and ( $ticket_as_user->$attribute() ne $cmds{ lc $attribute } ) );

            _SetAttribute(
                $ticket_as_user,        $attribute,
                $cmds{ lc $attribute }, \%results
            );
        }

        foreach my $attribute (@DATE_ATTRIBUTES) {
            next unless ( $cmds{ lc $attribute } );
            my $date = RT::Date->new( $args{'CurrentUser'} );
            $date->Set(
                Format => 'unknown',
                Value  => $cmds{ lc $attribute }
            );
            _SetAttribute( $ticket_as_user, $attribute, $date->ISO,
                \%results );
            $results{ lc $attribute }->{value} = $cmds{ lc $attribute };
        }

        foreach my $type ( qw(Requestor Cc AdminCc) ) {
            my %tmp = _ParseAdditiveCommand( \%cmds, 1, $type );
            next unless keys %tmp;

            $tmp{'Default'} = [ do {
                my $method = $type;
                $method .= 's' if $type eq 'Requestor';
                $args{'Ticket'}->$method->MemberEmailAddresses;
            } ];
            my ($add, $del) = _CompileAdditiveForUpdate( %tmp );
            foreach ( @$del ) {
                my ( $val, $msg ) = $ticket_as_user->DeleteWatcher(
                    Type  => $type,
                    Email => $_,
                );
                push @{ $results{ 'Del'. $type } }, {
                    value   => $_,
                    result  => $val,
                    message => $msg
                };
            }
            foreach ( @$add ) {
                my ( $val, $msg ) = $ticket_as_user->AddWatcher(
                    Type  => $type,
                    Email => $_,
                );
                push @{ $results{ 'Add'. $type } }, {
                    value   => $_,
                    result  => $val,
                    message => $msg
                };
            }
        }

        foreach my $type ( @LINK_ATTRIBUTES ) {
            my %tmp = _ParseAdditiveCommand( \%cmds, 1, $type );
            next unless keys %tmp;

            my $link_type = $ticket_as_user->LINKTYPEMAP->{ $type }->{'Type'};
            my $link_mode = $ticket_as_user->LINKTYPEMAP->{ $type }->{'Mode'};

            $tmp{'Default'} = [ do {
                my $links = $args{'Ticket'}->_Links( $link_mode, $link_type );
                my %h = ( Base => 'Target', Target => 'Base' );
                my @res;
                while ( my $link = $links->Next ) {
                    my $method = $h{$link_mode} .'URI';
                    my $uri = $link->$method();
                    next unless $uri->IsLocal;
                    push @res, $uri->Object->Id;
                }
                @res;
            } ];
            my ($add, $del) = _CompileAdditiveForUpdate( %tmp );
            foreach ( @$del ) {
                my ($val, $msg) = $ticket_as_user->DeleteLink(
                    Type => $link_type,
                    $link_mode => $_,
                );
                $results{ 'Del'. $type } = {
                    value => $_,
                    result => $val,
                    message => $msg,
                };
            }
            foreach ( @$add ) {
                my ($val, $msg) = $ticket_as_user->AddLink(
                    Type => $link_type,
                    $link_mode => $_,
                );
                $results{ 'Add'. $type } = {
                    value => $_,
                    result => $val,
                    message => $msg,
                };
            }
        }

        my $custom_fields = $queue->TicketCustomFields;
        while ( my $cf = $custom_fields->Next ) {
            warn "Updating CF ". $cf->Name;
            my %tmp = _ParseAdditiveCommand( \%cmds, 0, "CustomField{". $cf->Name ."}" );
            next unless keys %tmp;

            $tmp{'Default'} = [ do {
                my $values = $args{'Ticket'}->CustomFieldValues( $cf->id );
                my @res;
                while ( my $value = $values->Next ) {
                    push @res, $value->Content;
                }
                @res;
            } ];
            my ($add, $del) = _CompileAdditiveForUpdate( %tmp );
            foreach ( @$del ) {
                my ( $val, $msg ) = $ticket_as_user->DeleteCustomFieldValue(
                    Field => $cf->id,
                    Value => $_
                );
                $results{ "DelCustomField{". $cf->Name ."}" } = {
                    value => $_,
                    result => $val,
                    message => $msg,
                };
            }
            foreach ( @$add ) {
                my ( $val, $msg ) = $ticket_as_user->AddCustomFieldValue(
                    Field => $cf->id,
                    Value => $_
                );
                $results{ "DelCustomField{". $cf->Name ."}" } = {
                    value => $_,
                    result => $val,
                    message => $msg,
                };
            }
        }
        warn YAML::Dump(\%results);
        return ( $args{'CurrentUser'}, $args{'AuthLevel'} );

    } else {

        warn "Create new ticket";

        my %create_args = ();
        foreach my $attr (@REGULAR_ATTRIBUTES) {
            next unless exists $cmds{ lc $attr };
            $create_args{$attr} = $cmds{ lc $attr };
        }
        foreach my $attr (@DATE_ATTRIBUTES) {
            next unless exists $cmds{ lc $attr };
            my $date = RT::Date->new( $args{'CurrentUser'} );
            $date->Set(
                Format => 'unknown',
                Value  => $cmds{ lc $attr }
            );
            $create_args{$attr} = $date->ISO;
        }

        # Canonicalize links
        foreach my $type ( @LINK_ATTRIBUTES ) {
            $create_args{ $type } = [ _CompileAdditiveForCreate( 
                _ParseAdditiveCommand( \%cmds, 0, $type ),
            ) ];
        }

        # Canonicalize custom fields
        my $custom_fields = $queue->TicketCustomFields;
        while ( my $cf = $custom_fields->Next ) {
            my %tmp = _ParseAdditiveCommand( \%cmds, 0, "CustomField{". $cf->Name ."}" );
            next unless keys %tmp;
            $create_args{ 'CustomField-' . $cf->id } = [ _CompileAdditiveForCreate(%tmp) ];
        }

        # Canonicalize watchers
        # First of all fetch default values
        foreach my $type ( qw(Requestor Cc AdminCc) ) {
            my %tmp = _ParseAdditiveCommand( \%cmds, 1, $type );
            $tmp{'Default'} = [ $args{'CurrentUser'}->id ] if $type eq 'Requestor';
            $tmp{'Default'} = [
                ParseCcAddressesFromHead(
                    Head        => $args{'Message'}->head,
                    CurrentUser => $args{'CurrentUser'},
                    QueueObj    => $args{'Queue'},
                )
            ] if $type eq 'Cc' && $RT::ParseNewMessageForTicketCcs;

            $create_args{ $type } = [ _CompileAdditiveForCreate( %tmp ) ];
        }

        # get queue unless mail contain it
        $create_args{'Queue'} = $args{'Queue'}->Id unless exists $create_args{'Queue'};

        # subject
        unless ( $create_args{'Subject'} ) {
            $create_args{'Subject'} = $args{'Message'}->head->get('Subject');
            chomp $create_args{'Subject'};
        }

        # If we don't already have a ticket, we're going to create a new
        # ticket
        warn YAML::Dump( \%create_args );

        my ( $id, $txn_id, $msg ) = $ticket_as_user->Create(
            %create_args,
            MIMEObj => $args{'Message'}
        );
        unless ( $id ) {
            $RT::Logger->error("Couldn't create ticket, fallback to standard mailgate: $msg");
            return ($args{'CurrentUser'}, $args{'AuthLevel'});
        }

        # now that we've created a ticket, we abort so we don't create another.
        $args{'Ticket'}->Load($id);
        return ( $args{'CurrentUser'}, -1 );

    }
}

sub _ParseAdditiveCommand {
    my ($cmds, $plural_forms, $base) = @_;
    my (%res);

    my @types = $base;
    push @types, $base.'s' if $plural_forms;
    push @types, 'Add'. $base;
    push @types, 'Add'. $base .'s' if $plural_forms;
    push @types, 'Del'. $base;
    push @types, 'Del'. $base .'s' if $plural_forms;

    foreach my $type ( @types ) {
        next unless defined $cmds->{lc $type};

        my @values = ref $cmds->{lc $type} eq 'ARRAY'?
            @{ $cmds->{lc $type} }: $cmds->{lc $type};

        if ( $type =~ /^\Q$base\Es?/ ) {
            push @{ $res{'Set'} }, @values;
        } elsif ( $type =~ /^Add/ ) {
            push @{ $res{'Add'} }, @values;
        } else {
            push @{ $res{'Del'} }, @values;
        }
    }

    warn YAML::Dump( {ParseAdditiveCommand => \%res});

    return %res;
}

sub _CompileAdditiveForCreate {
    my %cmd = @_;
    my @list;
    @list = @{ $cmd{'Default'} } if $cmd{'Default'} && !$cmd{'Set'};
    @list = @{ $cmd{'Set'} } if $cmd{'Set'};
    push @list, @{ $cmd{'Add'} } if $cmd{'Add'};
    if ( $cmd{'Del'} ) {
        my %seen;
        $seen{$_} = 1 foreach @{ $cmd{'Del'} };
        @list = grep !$seen{$_}, @list;
    }
    return @list;
}

sub _CompileAdditiveForUpdate {
    my %cmd = @_;

    my @new = _CompileAdditiveForCreate( %cmd );

    my ($add, $del);
    if ( !$cmd{'Default'} ) {
        $add = \@new;
    } elsif ( !@new ) {
        $del = $cmd{'Default'};
    } else {
        my (%cur, %new);
        $cur{$_} = 1 foreach @{ $cmd{'Default'} };
        $new{$_} = 1 foreach @new;
        my %tmp;
        $add = [ grep !$cur{$_}, @new ];
        $del = [ grep !$new{$_}, @{ $cmd{'Default'} } ];
    }
    foreach ($add, $del) {
        $_ = [] unless $_;
    }
    warn YAML::Dump( {CompileForUpdate => [$add, $del]});
    return $add, $del;
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

sub _CanonicalizeCommand {
    my $key = shift;
    # CustomField commands
    $key =~ s/^(add|del|)c(?:field)?-?f(?:ield)?\.?[({\[](.*)[)}\]]$/$1customfield{$2}/i;
    return $key;
}

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
        value   => $email,
        result  => $val,
        message => $msg
    };

}



sub _ReportResults {
    my $report = shift;
    my $recipient = shift;

    my $report_msg = '';

    foreach my $key ( keys %$report ) {
        unless $result
#        $report_msg .= $key.":".$report->{$key}->{'value'};
    }


}

1;
