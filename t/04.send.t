#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 1;

use File::Temp qw/ tempfile tempdir /;

BEGIN { require 't/utils.pl' }
RT::Init;

diag("test errors via mailgate") if $ENV{'TEST_VERBOSE'};
{
    my $message_id = "foobar-$$\@example.com";
    my $text = <<END;
Subject: error test
From: root\@localhost
Message-Id: $message_id

Owner: this-user-does-not-exist\@example.com

test
END

    my ($fh, $filename) = tempfile();
    diag("Tempfile: $filename");
    if (RT->can('Config') && RT->Config->can('Set')) {
        RT->Config->Set(MailCommand => 'sendmailpipe');
        RT->Config->Set(SendmailPath => "cat > $filename");
        RT->Config->Set(SendmailBounceArguments => '');
        RT->Config->Set(SendmailArguments => '');
    } else {
        $RT::MailCommand = 'sendmailpipe';
        $RT::SendmailPath = "cat > $filename";
        $RT::SendmailBounceArguments = '';
        $RT::SendmailArguments = '';
    }

    use RT::EmailParser;
    my $parser = RT::EmailParser->new();
    $parser->ParseMIMEEntityFromScalar($text);

    RT::Interface::Email::MailError(
        To      => 'root@localhost',
        Subject => "Extended mailgate error",
        Explanation => "FUBARed",
        MIMEObj => $parser->Entity,
    );

    ok( (grep { /^In-Reply-To: $message_id$/ } <$fh>), "Set the In-Reply-To: header properly" );
}

1;
