use 5.008003;
package RT::Extension::CommandByMail;

our $VERSION = '0.16';

1;
__END__

=head1 NAME

RT::Extension::CommandByMail - Change metadata of ticket via email

=head1 SYNOPSIS

    Status: stalled
    Subject: change subject
    AddAdminCc: boss@example.com
    AddCc: dev1@example.com
    AddCc: dev2@example.com

    The comment/reply text goes here

=head1 DESCRIPTION

This extension allows you to manage tickets via email interface.  You
may put commands into the beginning of a mail, and extension will apply
them. See the list of commands in the
L<RT::Interface::Email::Filter::TakeAction> docs.

B<CAVEAT:> commands are line oriented, so you can't expand to multiple
lines for each command, i.e. values can't contains new lines. The module
also currently expects and parses text, not HTML.

=head1 SECURITY

This extension has no extended auth system; so all security issues that
apply to the RT in general also apply to the extension.

=head1 INSTALLATION

=over

=item C<perl Makefile.PL>

=item C<make>

=item C<make install>

May need root permissions

=item Edit your F</opt/rt4/etc/RT_SiteConfig.pm>

Add this line:

    Set(@Plugins, ( @Plugins, "RT::Extension::CommandByMail" ));

As well as:

    Set(@MailPlugins, qw(Auth::MailFrom Filter::TakeAction));

If you already have a C<@MailPlugins> configuration line, add
C<Filter::TakeAction> B<after> any authentication plugins (such as
C<Auth::MailFrom> or C<Auth::Crypt>).

=item Restart your webserver

=back

=head1 CONFIGURATION

=head2 C<$CommandByMailGroup>

You may set a C<$CommandByMailGroup> to a particular group ID in RT_SiteConfig.
If set, only members of this group may perform commands by mail.

=head2 C<$CommandByMailHeader>

You may set this configuration value to the name of a header to examine
as well.  For example:

    Set($CommandByMailHeader, "X-RT-Command");

=head2 C<$CommandByMailOnlyHeaders>

If set, the body will not be examined, only the headers.

=head1 COMMANDS

This extension parses the body and headers of incoming messages
for list commands. Format of commands is:

    Command: value
    Command: value
    ...

See the list of commands in the L<RT::Interface::Email::Filter::TakeAction> docs.

=head1 CAVEATS

This extension is incompatible with C<UnsafeEmailCommands> RT option.

=head1 AUTHOR

Jesse Vincent  C<< <jesse@bestpractical.com> >>
Ruslan U. Zakirov  C<< <ruz@bestpractical.com> >>
Kevin Falcone C<< <falcone@bestpractical.com> >>
Shawn Moore C<< <sartak@bestpractical.com> >>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2013, Best Practical Solutions, LLC.  All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

