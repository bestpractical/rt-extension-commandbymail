package RT::Extension::CommandByMail;

our $VERSION = '0.01';

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

=head1 SECURITY

This extension has no extended auth system, so all security issues
that applies to the RT in general also applies to the extension.

=head1 INSTALLATION AND CONFIGURATION

Read L<INSTALL>. Note that you B<must patch> RT
to use this extension, so read the file.

=head1 CAVEATS

This extension is incomatible with C<UnsafeEmailCommands> RT option.

=head1 AUTHOR

Jesse Vincent  C<< <jesse@bestpractical.com> >>
Ruslan U. Zakirov  C<< <ruz@bestpractical.com> >>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006, Best Practical Solutions, LLC.  All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

