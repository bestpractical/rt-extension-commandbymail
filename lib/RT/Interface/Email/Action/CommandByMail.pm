package RT::Interface::Email::Action::CommandByMail;

use warnings;
use strict;

use Role::Basic 'with';
with 'RT::Interface::Email::Role';

=head1 NAME

RT::Interface::Email::Action::CommandByMail - Change metadata of ticket via email

=head1 DESCRIPTION

This action provides compatibility with the new mail plugin system introduced
in RT 4.4. It provides an alternate to the default comment and correspond
handlers provided by RT.

=cut

# To maintain compatibility with previous versions of CommandByMail,
# handle the standard comment and correspond actions. Follow the
# pattern from RT's default action handling for providing both.

sub HandleComment {
    _HandleEither( @_, Action => "Comment" );
}

sub HandleCorrespond {
    _HandleEither( @_, Action => "Correspond" );
}

sub _HandleEither {
    my %args = (
        Action      => undef,
        Message     => undef,
        Subject     => undef,
        Ticket      => undef,
        TicketId    => undef,
        Queue       => undef,
        @_,
    );

    my $return_ref = RT::Extension::CommandByMail::ProcessCommands(%args);

    if ( exists $return_ref->{'MailError'} and $return_ref->{'MailError'} ){
        MailError(
            Subject     => $return_ref->{'ErrorSubject'},
            Explanation => $return_ref->{'Explanation'},
            FAILURE     => $return_ref->{'Failure'},
        );
    }
    return;
}

1;
