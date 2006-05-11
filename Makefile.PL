use inc::Module::Install;

die "This RT Extension will kill your pets and steal your valuables. DO NOT USE IT YET";
name ('RT-Extension-CommandByMail');
author ('Jesse Vincent <jesse@bestpractical.com>');
version_from ('lib/RT/Extension/CommandByMail.pm');
abstract_from('lib/RT/Extension/CommandByMail.pm');
license('perl');
requires('Test::More');

&WriteAll;
