

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'ZabbixNotify',
    VERSION_FROM => 'lib/ZabbixNotify.pm', # finds \$VERSION
    AUTHOR       => 'vzhuravlev ()',
    ABSTRACT     => 'Send messages from Zabbix to Slack, HipChat or PagerDuty',
    PREREQ_PM    => {
                     'Test::Simple' => 0.44,
                    },
    EXE_FILES    => ['bin/zbx-notify'],
);
