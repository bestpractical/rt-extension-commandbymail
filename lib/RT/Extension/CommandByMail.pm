package RT::Extension::CommandByMail;

our $VERSION = '0.08_01';

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

    Here goes comment/reply

=head1 DESCRIPTION

This extension allows you to manage tickets via email interface.
You put commands into beginning of a mail and extension applies
them. See the list of commands in the
L<RT::Interface::Email::Filter::TakeAction> docs.

CAVEAT: commands are line oriented, so you can't expand to multiple
lines for each command, i.e. values can't contains new lines.

=head1 SECURITY

This extension has no extended auth system, so all security issues
that applies to the RT in general also applies to the extension.

=head1 INSTALLATION AND CONFIGURATION

Read L<INSTALL>. Note that you B<must patch> RT
to use this extension, so read the file.

=head2 C<$CommandByMailGroup>

You may set a C<$CommandByMailGroup> to a particular group ID in RT_SiteConfig.
If set, only members of this group may perform commands by mail.

=head1 CAVEATS

This extension is incomatible with C<UnsafeEmailCommands> RT option.

=head1 AUTHOR

Jesse Vincent  C<< <jesse@bestpractical.com> >>
Ruslan U. Zakirov  C<< <ruz@bestpractical.com> >>
Kevin Falcone C<< <falcone@bestpractical.com> >>
Shawn Moore C<< <sartak@bestpractical.com> >>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2008, Best Practical Solutions, LLC.  All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

