use inc::Module::Install;

#die "This RT Extension will kill your pets and steal your valuables. DO NOT USE IT YET";
RTx ('RT-Extension-CommandByMail');
author ('Jesse Vincent <jesse@bestpractical.com>');
license('perl');

build_requires('Test::More');
build_requires('IPC::Open2');

# the patch for RT-3.4.5 has this requirement
# RT may be require it too, but put it here to be sure 
requires('UNIVERSAL::require');
requires('MIME::Entity' => '5.420');
auto_install();

my ($lp) = ($INC{'RT.pm'} =~ /^(.*)[\\\/]/);
my $lib_path = join( ' ', "$RT::LocalPath/lib", $lp );
my $sbin_path = $RT::SbinPath || "$RT::BasePath/sbin" || "/opt/rt3/sbin";
my $bin_path = $RT::BinPath || "$RT::BasePath/bin" || "/opt/rt3/bin";

substitute(
    {
        RT_LIB_PATH  => $lib_path,
        RT_BIN_PATH  => $bin_path,
        RT_SBIN_PATH => $sbin_path,
    },
    qw(t/utils.pl),
);


WriteAll();
