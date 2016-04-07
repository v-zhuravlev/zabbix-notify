

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'SlackBot',
    VERSION_FROM => 'lib/SlackBot.pm', # finds \$VERSION
    AUTHOR       => 'vzhuravlev ()',
    ABSTRACT     => 'Send messages from Zabbix to Slack',
    PREREQ_PM    => {
                     'Test::Simple' => 0.44,
                    },
    EXE_FILES    => ['bin/zbx-slack'],
);
