use Test::More tests => 3;

BEGIN { require 't/utils.pl' }
BEGIN {
    use_ok( 'RT' );
    RT::LoadConfig();
    use_ok( 'RT::Extension::CommandByMail' );
    use_ok( 'RT::Interface::Email::Filter::TakeAction' );
}

diag( "Testing RT::Extension::CommandByMail $RT::Extension::CommandByMail::VERSION" );
