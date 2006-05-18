use inc::Module::Install;

#die "This RT Extension will kill your pets and steal your valuables. DO NOT USE IT YET";
RTx ('RT-Extension-CommandByMail');
author ('Jesse Vincent <jesse@bestpractical.com>');
license('perl');

# the patch for RT-3.4.5 has this requirement
# RT may be require it too, but put it here to be sure 
requires('UNIVERSAL::require');
build_requires('Test::More');

WriteAll();
