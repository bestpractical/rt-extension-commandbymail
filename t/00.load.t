use Test::More tests => 5;

BEGIN { require 't/utils.pl' }
BEGIN {
    use_ok( 'RT' );
    RT::LoadConfig();
    use_ok( 'RT::Extension::CommandByMail' );
    use_ok( 'RT::Interface::Email::Filter::TakeAction' );
}

diag( "Testing RT::Extension::CommandByMail $RT::Extension::CommandByMail::VERSION" );

my $new_config = RT->can('Config') && RT->Config->can('Get');

my @plugins = $new_config
            ? RT->Config->Get('Plugins')
            : @RT::Plugins;

my @mail_plugins = $new_config
                 ? RT->Config->Get('MailPlugins')
                 : @RT::MailPlugins;

my $complain = 0;
ok((grep { $_ eq 'RT::Extension::CommandByMail' } @plugins), "RT::Extension::CommandByMail is in your config's \@Plugins") or $complain = 1;
ok((grep { $_ eq 'Filter::TakeAction' } @mail_plugins), "Filter::TakeAction is in your config's \@MailPlugins") or $complain = 1;

if ($complain) {
    diag "Please read through the entire INSTALL documentation for directions on how to set up your config for testing and using this plugin.";
}

