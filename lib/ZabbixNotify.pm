package ZabbixNotify;
use strict;
use warnings;
our $VERSION = '0.4';

use Carp;
use JSON::XS;
use Data::Dumper;

use constant { ## no critic(ProhibitConstantPragma)
    STORAGEFILE            => '/var/tmp/zbx-slack-temp-storage',
};


=zbx_macro_to_json
transform everything(zabbix macros) in double squares [[ ]] to json STRING
note that unicode chars already encoded to \u1234 currently in message when called.
=cut
sub zbx_macro_to_json {
     my $self = shift;
     my $message = shift;
     my $orig ;
     my $result ;
            
        while (  $message =~ /( \[ \[) (.*?) (\] \] ) /gxs) {
            
            $orig = $1.$2.$3;
            $result = $2;
            print $orig."\n";
            #order matters
            utf8::encode( $result);
            $result =~  s/ \\ /\\\\/xg; #\
            $result =~  s/ \/ /\\\//xg; #/
            $result =~  s/ " /\\"/xg; #"
            $result =~  s/ \n /\\n/xg; #\n
            $result =~  s/ \r /\\r/xg; #\r
            $result =~  s/ \x{8} //xg; #backspace
            $result =~  s/ \x{C} //xg; #formfeed
            $result =~  s/ \x{9} /    /xg; #horizontal tab
            utf8::decode( $result);
                        
            $orig = quotemeta($orig);
            
            $message =~ s/$orig/$result/;
        }
        print $message."\n";
        return $message;

}


sub DESTROY { }

1;
