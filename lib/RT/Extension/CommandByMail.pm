use 5.008003;
package RT::Extension::CommandByMail;

our $VERSION = '1.00';

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

If you are using RT 4.2 or greater, add this line:

    Plugin('RT::Extension::CommandByMail');

For RT 4.0, add this line:

    Set(@Plugins, qw(RT::Extension::CommandByMail));

or add C<RT::Extension::CommandByMail> to your existing C<@Plugins> line.

Regardless of which version of RT, also C<Filter::TakeAction> to your
C<@MailPlugins> configuration, as follows:

    Set(@MailPlugins, qw(Auth::MailFrom Filter::TakeAction));

Be sure to include C<Auth::MailFrom> in the list as well.

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

Best Practical Solutions, LLC E<lt>modules@bestpractical.comE<gt>

=head1 BUGS

All bugs should be reported via email to

    L<bug-RT-Extension-CommandByMail@rt.cpan.org|mailto:bug-RT-Extension-CommandByMail@rt.cpan.org>

or via the web at

    L<rt.cpan.org|http://rt.cpan.org/Public/Dist/Display.html?Name=RT-Extension-CommandByMail>.

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2014 by Best Practical Solutions

This is free software, licensed under:

  The GNU General Public License, Version 2, June 1991

=cut

