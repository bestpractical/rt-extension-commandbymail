package RT::Interface::Email::Filter::TakeAction;

use warnings;
use strict;

use RT::Interface::Email;

our @REGULAR_ATTRIBUTES = qw(Queue Owner Subject Status Priority FinalPriority);
our @TIME_ATTRIBUTES    = qw(TimeWorked TimeLeft TimeEstimated);
our @DATE_ATTRIBUTES    = qw(Due Starts Started Resolved Told);
our @LINK_ATTRIBUTES    = qw(MemberOf Parents Members Children
            HasMember RefersTo ReferredToBy DependsOn DependedOnBy);
our @WATCHER_ATTRIBUTES = qw(Requestor Cc AdminCc);

=head1 NAME

RT::Interface::Email::Filter::TakeAction - Change metadata of ticket via email

=head1 DESCRIPTION

This extension parse content of incomming messages for list commands. Format
of commands is:

    Command: value
    Command: value
    ...

You can find list of L</COMMANDS commands below>.

Some commands (like Status, Queue and other) can be used only once. Commands
that manage lists can be used multiple times, for example link, custom fields
and watchers commands. Also, the latter can be used with C<Add> and C<Del>
prefixes to add/delete values from the current list of the ticket you reply to
or comment on.

=head2 COMMANDS

=head3 Basic

=over 4

=item Queue: <name>

Set new queue for the ticket

=item Subject: <string>

Set new subject to the given string

=item Status: <status>

Set new status, one of new, open, stalled, resolved, rejected or deleted

=item Owner: <username>

Set new owner using the given username

=item Priority: <#>

Set new priority to the given value

=item FinalPriority: <#>

Set new final priority to the given value

=back

=head3 Dates

Set new date/timestamp, or 0 to unset:

    Due: <new timestamp>
    Starts: <new timestamp>
    Started: <new timestamp>

=head3 Time

Set new times to the given value in minutes. Note that
on correspond/comment B<< C<TimeWorked> add time >> to the current
value.

    TimeWorked: <minutes>
    TimeEstimated: <minutes>
    TimeLeft: <minutes>

=head3 Watchers

Manage watchers: requestors, ccs and admin ccs. This commands
can be used several times and/or with C<Add> and C<Del> prefixes,
for example C<Requestor> comand set requestor(s) and the current
requestors would be deleted, but C<AddRequestor> command adds
to the current list.

    Requestor: <address> Set requestor(s) using the email address
    AddRequestor: <address> Add new requestor using the email address
    DelRequestor: <address> Remove email address as requestor
    Cc: <address> Set Cc watcher(s) using the email address
    AddCc: <address> Add new Cc watcher using the email address
    DelCc: <address> Remove email address as Cc watcher
    AdminCc: <address> Set AdminCc watcher(s) using the email address
    AddAdminCc: <address> Add new AdminCc watcher using the email address
    DelAdminCc: <address> Remove email address as AdminCc watcher

=head3 Links

Manage links. These commands are also could be used several times in one
message.

    DependsOn: <ticket id>
    DependedOnBy: <ticket id>
    RefersTo: <ticket id>
    ReferredToBy: <ticket id>
    Members: <ticket id>
    MemberOf: <ticket id>

=head3 Custom field values

Manage custom field values. Could be used multiple times.

    CustomField.{C<CFName>}: <custom field value>
    AddCustomField.{C<CFName>}: <custom field value>
    DelCustomField.{C<CFName>}: <custom field value>

Short forms:

    CF.{C<CFName>}: <custom field value>
    AddCF.{C<CFName>}: <custom field value>
    DelCF.{C<CFName>}: <custom field value>

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

    unless ( $args{'CurrentUser'} ) {
        $RT::Logger->error(
            "Filter::TakeAction executed when "
            ."CurrentUser (actor) is not authorized. "
            ."Most probably you want to add Auth::MailFrom plugin before."
        );
        return ( $args{'CurrentUser'}, $args{'AuthLevel'} );
    }

    # If the user isn't asking for a comment or a correspond,
    # bail out
    unless ( $args{'Action'} =~ /^(?:comment|correspond)$/i ) {
        return ( $args{'CurrentUser'}, $args{'AuthLevel'} );
    }

    my @content;
    my @parts = $args{'Message'}->parts_DFS;
    foreach my $part (@parts) {
        my $body = $part->bodyhandle or next;

        #if it looks like it has pseudoheaders, that's our content
        if ( $body->as_string =~ /^(?:\S+):/m ) {
            @content = $body->as_lines;
            last;
        }
    }

    my @items;
    foreach my $line (@content) {
        last if $line !~ /^(?:(\S+)\s*?:\s*?(.*)\s*?|)$/;
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

    my %results;

    foreach my $cmd ( keys %cmds ) {
        my ($val, $msg) = _CheckCommand( $cmd );
        unless ( $val ) {
            $results{ $cmd } = {
                value   => delete $cmds{ $cmd },
                result  => $val,
                message => $msg,
            };
        }
    }

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

        # we set status later as correspond can reopen ticket
        foreach my $attribute (grep !/^(Status|TimeWorked)/, @REGULAR_ATTRIBUTES, @TIME_ATTRIBUTES) {
            next unless defined $cmds{ lc $attribute };
            next if $ticket_as_user->$attribute() eq $cmds{ lc $attribute };

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
                Value  => $cmds{ lc $attribute },
            );
            _SetAttribute( $ticket_as_user, $attribute, $date->ISO,
                \%results );
            $results{ lc $attribute }->{value} = $cmds{ lc $attribute };
        }

        foreach my $type ( @WATCHER_ATTRIBUTES ) {
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

        {
            my $time_taken = 0;
            $time_taken = $cmds{'timeworked'} || 0
                if grep $_ eq 'TimeWorked', @TIME_ATTRIBUTES;

            my $method = ucfirst $args{'Action'};
            my ($status, $msg) = $ticket_as_user->$method(
                TimeTaken => $time_taken,
                MIMEObj   => $args{'Message'},
            );
            unless ( $status ) {
                $RT::Logger->warning(
                    "Couldn't write $args{'Action'}."
                    ." Fallback to standard mailgate. Error: $msg");
                return ( $args{'CurrentUser'}, $args{'AuthLevel'} );
            }
        }

        foreach my $type ( @LINK_ATTRIBUTES ) {
            my %tmp = _ParseAdditiveCommand( \%cmds, 1, $type );
            next unless keys %tmp;

            my $link_type = $ticket_as_user->LINKTYPEMAP->{ $type }->{'Type'};
            my $link_mode = $ticket_as_user->LINKTYPEMAP->{ $type }->{'Mode'};

            $tmp{'Default'} = [ do {
                my %h = ( Base => 'Target', Target => 'Base' );
                my $links = $args{'Ticket'}->_Links( $h{$link_mode}, $link_type );
                my @res;
                while ( my $link = $links->Next ) {
                    my $method = $link_mode .'URI';
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

        foreach my $attribute (grep $_ eq 'Status', @REGULAR_ATTRIBUTES) {
            next unless defined $cmds{ lc $attribute };
            next if $ticket_as_user->$attribute() eq $cmds{ lc $attribute };

            _SetAttribute(
                $ticket_as_user,        $attribute,
                $cmds{ lc $attribute }, \%results
            );
        }

        _ReportResults(
            Ticket => $args{'Ticket'},
            Results => \%results,
            Message => $args{'Message'}
        );
        return ( $args{'CurrentUser'}, -2 );

    } else {

        my %create_args = ();
        foreach my $attr (@REGULAR_ATTRIBUTES, @TIME_ATTRIBUTES) {
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
        foreach my $type ( @WATCHER_ATTRIBUTES ) {
            my %tmp = _ParseAdditiveCommand( \%cmds, 1, $type );
            $tmp{'Default'} = [ $args{'CurrentUser'}->EmailAddress ] if $type eq 'Requestor';
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

        my ( $id, $txn_id, $msg ) = $ticket_as_user->Create(
            %create_args,
            MIMEObj => $args{'Message'}
        );
        unless ( $id ) {
            $msg = "Couldn't create ticket from message with commands, ".
                   "fallback to standard mailgate.\n\nError: $msg";
            $RT::Logger->error( $msg );
            $results{'Create'} = {
                result => $id,
                message => $msg,
            };

            _ReportResults( Results => \%results, Message => $args{'Message'} );

            return ($args{'CurrentUser'}, $args{'AuthLevel'});
        }

        _ReportResults( Results => \%results, Message => $args{'Message'} );

        # now that we've created a ticket, we abort so we don't create another.
        $args{'Ticket'}->Load( $id );
        return ( $args{'CurrentUser'}, -2 );
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

    return %res;
}

sub _CompileAdditiveForCreate {
    my %cmd = @_;

    unless ( exists $cmd{'Default'} && defined $cmd{'Default'} ) {
        $cmd{'Default'} = [];
    } elsif ( ref $cmd{'Default'} ne 'ARRAY' ) {
        $cmd{'Default'} = [ $cmd{'Default'} ];
    }

    my @list;
    @list = @{ $cmd{'Default'} } unless $cmd{'Set'};
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

    unless ( exists $cmd{'Default'} && defined $cmd{'Default'} ) {
        $cmd{'Default'} = [];
    } elsif ( ref $cmd{'Default'} ne 'ARRAY' ) {
        $cmd{'Default'} = [ $cmd{'Default'} ];
    }

    my ($add, $del);
    unless ( @{ $cmd{'Default'} } ) {
        $add = \@new;
    } elsif ( !@new ) {
        $del = $cmd{'Default'};
    } else {
        my (%cur, %new);
        $cur{$_} = 1 foreach @{ $cmd{'Default'} };
        $new{$_} = 1 foreach @new;

        $add = [ grep !$cur{$_}, @new ];
        $del = [ grep !$new{$_}, @{ $cmd{'Default'} } ];
    }
    $_ ||= [] foreach ($add, $del);
    return ($add, $del);
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
    $key =~ s/^(add|del|)c(?:ustom)?-?f(?:ield)?\.?[({\[](.*)[)}\]]$/$1customfield{$2}/i;
    return $key;
}

sub _CheckCommand {
    my ($cmd, $val) = (lc shift, shift);
    return 1 if $cmd =~ /^(add|del|)customfield{.*}$/i;
    if ( grep $cmd eq lc $_, @REGULAR_ATTRIBUTES, @TIME_ATTRIBUTES, @DATE_ATTRIBUTES ) {
        return 1 unless ref $val;
        return (0, "Command '$cmd' doesn't support multiple values");
    }
    return 1 if grep $cmd eq lc $_, @LINK_ATTRIBUTES, @WATCHER_ATTRIBUTES;
    if ( $cmd =~ /^(?:add|del)(.*)$/i ) {
        my $cmd = $1;
        if ( grep $cmd eq lc $_, @REGULAR_ATTRIBUTES, @TIME_ATTRIBUTES, @DATE_ATTRIBUTES ) {
            return (0, "Command '$cmd' doesn't support multiple values");
        }
        return 1 if grep $cmd eq lc $_, @LINK_ATTRIBUTES, @WATCHER_ATTRIBUTES;
    }

    return (0, "Command '$cmd' is unkown");
}

sub _ReportResults {
    my %args = ( Ticket => undef, Message => undef, Results => {}, @_ );

    my $msg = '';
    unless ( $args{'Ticket'} ) {
        $msg .= $args{'Results'}{'Create'}{'message'} || '';
        $msg .= "\n" if $msg;
        delete $args{'Results'}{'Create'};
    }

    foreach my $key ( keys %{ $args{'Results'} } ) {
        my @records = ref $args{'Results'}->{ $key } eq 'ARRAY'?
                         @{$args{'Results'}->{ $key }}: $args{'Results'}->{ $key };
        foreach my $rec ( @records ) {
            next if $rec->{'result'};
            $msg .= "Failed command '". $key .": ". $rec->{'value'} ."'\n";
            $msg .= "Error message: ". ($rec->{'message'}||"(no message)") ."\n\n";
        }
    }
    return unless $msg && $msg !~ /^\s*$/;

    $RT::Logger->warning( $msg );
    my $ErrorsTo = RT::Interface::Email::ParseErrorsToAddressFromHead( $args{'Message'}->head );
    RT::Interface::Email::MailError(
        To          => $ErrorsTo,
        Subject     => "Extended mailgate error",
        Explanation => $msg,
        MIMEObj     => $args{'Message'},
    );
    return;
}

1;
