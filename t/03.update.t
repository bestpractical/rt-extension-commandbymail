#!/usr/bin/perl

use strict;
use warnings;

use Test::More qw(no_plan);

BEGIN { require 't/utils.pl' }
RT::Init();

my $test_ticket_id;

diag("simle test of the mailgate") if $ENV{'TEST_VERBOSE'};
{
    my $text = <<END;
Subject: test
From: root\@localhost

test
END
    my $id = create_ticket_via_gate( $text );
    ok($id, "created ticket");
    my $obj = RT::Ticket->new( $RT::SystemUser );
    $obj->Load( $id );
    is($obj->id, $id, "loaded ticket");
    $test_ticket_id = $id;
}

# XXX: use statuses from config/libs
diag("set status on update") if $ENV{'TEST_VERBOSE'};
foreach my $status ( qw(new open stalled rejected) ) {
    my $text = <<END;
Subject: [$RT::rtname #$test_ticket_id] test
From: root\@localhost

Status: $status

test
END
    my $id = create_ticket_via_gate( $text );
    is($id, $test_ticket_id, "updated ticket");
    my $obj = RT::Ticket->new( $RT::SystemUser );
    $obj->Load( $id );
    is($obj->id, $id, "loaded ticket");
    is($obj->Status, $status, 'set status' );
}

diag("set priority and final_priority on create") if $ENV{'TEST_VERBOSE'};
foreach my $priority ( 10, 20 ) { foreach my $final_priority ( 5, 15, 20 ) {
    my $text = <<END;
Subject: [$RT::rtname #$test_ticket_id] test
From: root\@localhost

Priority: $priority
FinalPriority: $final_priority

test
END
    my $id = create_ticket_via_gate( $text );
    is($id, $test_ticket_id, "updated ticket");
    my $obj = RT::Ticket->new( $RT::SystemUser );
    $obj->Load( $id );
    is($obj->id, $id, "loaded ticket");
    is($obj->Priority, $priority, 'set priority' );
    is($obj->FinalPriority, $final_priority, 'set final priority' );
} }

diag("set date on update") if $ENV{'TEST_VERBOSE'};
foreach my $field ( qw(Due Starts Started) ) {
    my $value = '2005-12-01 12:34:00';
    my $date_obj = RT::Date->new( $RT::System );
    $date_obj->Set( Format => 'unknown', Value => $value );

    my $text = <<END;
Subject: [$RT::rtname #$test_ticket_id] test
From: root\@localhost

$field: $value

test
END
    my $id = create_ticket_via_gate( $text );
    is($id, $test_ticket_id, "updated ticket");
    my $obj = RT::Ticket->new( $RT::SystemUser );
    $obj->Load( $id );
    is($obj->id, $id, "loaded ticket");
    my $method = $field .'Obj';
    is($obj->$method->ISO, $date_obj->ISO, 'set date' );
}

diag("set time on update") if $ENV{'TEST_VERBOSE'};
foreach my $field ( qw(TimeWorked TimeEstimated TimeLeft) ) {
    my $value = 1 + int rand 10;
    my $text = <<END;
Subject: [$RT::rtname #$test_ticket_id] test
From: root\@localhost

$field: $value

test
END
    my $id = create_ticket_via_gate( $text );
    is($id, $test_ticket_id, "updated ticket");
    my $obj = RT::Ticket->new( $RT::SystemUser );
    $obj->Load( $id );
    is($obj->id, $id, "loaded ticket");
    is($obj->$field(), $value, 'set time' );
}


diag("check time worked additivness") if $ENV{'TEST_VERBOSE'};
{
    my $obj = RT::Ticket->new( $RT::SystemUser );
    $obj->Load( $test_ticket_id );
    is($obj->id, $test_ticket_id, "loaded ticket");
    my $current = $obj->TimeWorked;
    ok($current, "time worked is greater than zero");

    my $text = <<END;
Subject: [$RT::rtname #$test_ticket_id] test
From: root\@localhost

TimeWorked: 10

test
END
    my $id = create_ticket_via_gate( $text );
    is($id, $test_ticket_id, "updated ticket");
    $obj = RT::Ticket->new( $RT::SystemUser );
    $obj->Load( $id );
    is($obj->id, $id, "loaded ticket");
    is($obj->TimeWorked, $current + 10, 'set time' );
}


diag("set watchers on update") if $ENV{'TEST_VERBOSE'};
foreach my $field ( qw(Requestor Cc AdminCc) ) {
    my $value = 'test@localhost';
    my $text = <<END;
Subject: [$RT::rtname #$test_ticket_id] test
From: root\@localhost

$field: $value

test
END
    my $id = create_ticket_via_gate( $text );
    is($id, $test_ticket_id, "updated ticket");
    my $obj = RT::Ticket->new( $RT::SystemUser );
    $obj->Load( $id );
    is($obj->id, $id, "loaded ticket");
    my $method = $field .'Addresses';
    is($obj->$method(), $value, 'set '. $field );
}

diag("add requestor on update") if $ENV{'TEST_VERBOSE'};
{
    my $value = 'test@localhost';
    my $text = <<END;
Subject: [$RT::rtname #$test_ticket_id] test
From: root\@localhost

AddRequestor: root\@localhost
AddRequestor: $value

test
END
    my $id = create_ticket_via_gate( $text );
    is($id, $test_ticket_id, "updated ticket");
    my $obj = RT::Ticket->new( $RT::SystemUser );
    $obj->Load( $id );
    is($obj->id, $id, "loaded ticket");
    is($obj->RequestorAddresses, "root\@localhost, $value", 'add requestor' );
}

diag("del requestor on update") if $ENV{'TEST_VERBOSE'};
{
    my $text = <<END;
Subject: [$RT::rtname #$test_ticket_id] test
From: root\@localhost

DelRequestor: root\@localhost

test
END
    my $id = create_ticket_via_gate( $text );
    is($id, $test_ticket_id, "updated ticket");
    my $obj = RT::Ticket->new( $RT::SystemUser );
    $obj->Load( $id );
    is($obj->id, $id, "loaded ticket");
    is($obj->RequestorAddresses, 'test@localhost', 'del requestor' );
}

my $link_ticket_id;
diag("create ticket for linking") if $ENV{'TEST_VERBOSE'};
{
    my $text = <<END;
Subject: test
From: root\@localhost

test
END
    my $id = create_ticket_via_gate( $text );
    ok($id, "created ticket");
    my $obj = RT::Ticket->new( $RT::SystemUser );
    $obj->Load( $id );
    is($obj->id, $id, "loaded ticket");
    $link_ticket_id = $id;
}

diag("set links on update") if $ENV{'TEST_VERBOSE'};
foreach my $field ( qw(DependsOn DependedOnBy RefersTo ReferredToBy Members MemberOf) ) {
    diag("test $field command") if $ENV{'TEST_VERBOSE'};
    my $text = <<END;
Subject: [$RT::rtname #$test_ticket_id] test
From: root\@localhost

$field: $link_ticket_id

test
END
    my $id = create_ticket_via_gate( $text );
    is($id, $test_ticket_id, "updated ticket");
    my $obj = RT::Ticket->new( $RT::SystemUser );
    $obj->Load( $id );
    is($obj->id, $id, "loaded ticket");

    my $links = $obj->$field();
    ok($links, "ticket has links");
    is($links->Count, 1, "one link");

    my $link_type = $obj->LINKTYPEMAP->{ $field }->{'Type'};
    my $link_mode = $obj->LINKTYPEMAP->{ $field }->{'Mode'};

    my $link = $links->First;
    is($link->Type, $link_type, "correct type");
    isa_ok($link, 'RT::Link');
    my $method = $link_mode .'Obj';
    is($link->$method()->Id, $link_ticket_id, 'set '. $field );
}

diag("set custom fields on update") if $ENV{'TEST_VERBOSE'};
{
    require RT::CustomField;
    my $cf = RT::CustomField->new( $RT::SystemUser );
    my $cf_name = 'test'.rand $$;
    $cf->Create( Name => $cf_name, Queue => 0, Type => 'Freeform' );
    ok($cf->id, "created global CF");

    my $text = <<END;
Subject: [$RT::rtname #$test_ticket_id] test
From: root\@localhost

CustomField.{$cf_name}: foo

test
END
    my $id = create_ticket_via_gate( $text );
    is($id, $test_ticket_id, "updated ticket");
    my $obj = RT::Ticket->new( $RT::SystemUser );
    $obj->Load( $id );
    is($obj->id, $id, "loaded ticket");
    is($obj->FirstCustomFieldValue($cf_name), 'foo', 'correct cf value' );
}

