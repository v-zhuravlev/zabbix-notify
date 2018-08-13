package SlackBot;
use strict;
use warnings;
our $VERSION = '0.8';
use parent qw(ZabbixNotify);
use LWP;
use URI;
use Carp;
use JSON::XS;
use Data::Dumper;
use Storable qw(lock_store lock_retrieve);

use constant { ## no critic(ProhibitConstantPragma)
    CLEAR_ALARM_AFTER_SECS => 30,
    STORAGEFILE            => '/var/tmp/zbx-slack-temp-storage',
    HTTP_TOO_MANY_REQUESTS => 429,
    RETRY_DEFAULT          => 2,
    RETRY_WAIT_SECS        => 5,
};

sub new {
    my $class = shift;
    my $args  = shift;

    my $web_api_url = $args->{web_api_url} || 'https://slack.com/api/';
    my $api_token = $args->{api_token}
      || croak " Failed to create Slack bot - No token provided";
    my $debug = $args->{debug} || 0;
    my $channel = $args->{channel};

    my $self = bless {
        api_token   => $api_token,
        web_api_url => $web_api_url,
        debug       => $debug,
        channel     => $channel,
        last_err    => '',
        mock_url    => undef
    }, $class;

    return $self;
}

sub channel {
    my $self = shift;
    if (@_) {
        my $channel = shift;
        validate_slack_channel($channel);
        return $self->{channel} = $channel;
    }
    else {
        return $self->{channel};
    }
}

sub test {
    my $self = shift;

    my $url = URI->new( $self->web_api_url . 'api.test' );
    $url->query_form( 'token' => $self->api_token );
    $self->get_with_retries($url);
    my $response      = $self->get_with_retries($url);
    my $json_contents = JSON::XS->new->utf8->decode( $response->content );

    return $json_contents;
}

sub post_message {
    my $self     = shift;
    my $contents = shift || die "No contents provided to post into Slack!\n";

    #prepare color:
    $contents->{color} = choose_color($contents);
 
    my $json_attach = $self->create_json_if_plain($contents);

    #Slack possible modes:
    # event - Notifications from Zabbix are posted in Slack in without any 'magic'
    # alarm - When problem is resolved in Zabbix - notification is updated in Slack and then deleted. 
    #         Acknowlegments are attached as replies to thread
    # alarm-no-delete - When problem is resolved in Zabbix - notification is updated in Slack but not deleted.
    #         Acknowlegments are attached as replies to thread
    

    if (($contents->{slack}->{mode} eq 'alarm' or $contents->{slack}->{mode} eq 'alarm-no-delete')
            and defined( $contents->{eventid} ) ) 
    {
        #alarm recovery
        if ($contents->{status} eq 'OK'){

            print "Alarm recovery message!\n";
            $self->post_recoveryMessage($contents,$json_attach);

        }
        else {
            print "Alarm message or plain event message or acknowledgement!\n";
            my $message;
            #here goes Slack threading
            $self->post_replyMessage($contents,$json_attach);
            
        }

    }
    else { #event mode
        my $message = $self->chat_postMessage( { attachments => $json_attach} );
    }



}

sub post_recoveryMessage {

    my $self = shift;
    my $contents = shift;
    my $json_attach = shift;
    my $mes_to_replace;

    if ( $mes_to_replace = retrieve_from_store( $contents->{eventid}, 1 ) ) {
        print Dumper $mes_to_replace if $self->debug;
        #always update first [0] message (thread start)
        $self->chat_updateMessage(
            {
                attachments => $json_attach,
                ts          => $mes_to_replace->[0]->{'ts'},
                channel     => $mes_to_replace->[0]->{'channel'},
                text        => $mes_to_replace->[0]->{'text'}
            }
        );
    }

    if ( not $mes_to_replace or $self->last_err eq 'message_not_found' ) {

        #post the recovery then
        print "No messages found to be deleted\n";

        my $message = $self->chat_postMessage( { attachments => $json_attach } );
        $mes_to_replace = [{
            ts      => $message->{'ts'},
            channel => $message->{'channel'}
        }];
    }

    #delete only if not 'alarm-no-delete' mode
    if ($contents->{slack}->{mode} ne 'alarm-no-delete'){
        sleep CLEAR_ALARM_AFTER_SECS;

        #delete thread starter and all replies
        foreach my $message_to_delete (@{$mes_to_replace}) {
            $self->chat_deleteMessage(
                {
                    ts      => $message_to_delete->{'ts'},
                    channel => $message_to_delete->{'channel'}
                }
            );
        }
    }

}

sub post_replyMessage {
    my $self = shift;
    my $contents = shift;
    my $json_attach = shift;

    if ( defined( $contents->{eventid} ) ) {
        #Probably a Reply(Acknowlegement)! Let's attach it to the Slack thread...
        my $mes_to_reply;
        #false(0) = means do not delete from store.
        if ( $mes_to_reply = retrieve_from_store( $contents->{eventid}, 0 ) ) {
            print "Found message to reply in Slack\n";
            print Dumper $mes_to_reply if $self->debug;
            #always use first [0] message found in store (thread start)
            my $message =
                $self->chat_postMessage( { attachments => $json_attach,
                                           thread_ts => $mes_to_reply->[0]->{ts} } );
            print "Storing event id...\n" if $self->{debug};
            store_message( $contents->{eventid}, $message );
        }
        else 
        {
            print "Posting message\n";
            my $message = $self->chat_postMessage( { attachments => $json_attach} );

            print "Storing event id...\n" if $self->{debug};
            store_message( $contents->{eventid}, $message );

        }
    }    
    
}

sub chat_postMessage {
    my $self = shift;
    my $args = shift;

    my $channel =
         $args->{channel}
      || $self->channel
      || die "Failed to postMessage: channel is required\n";

    #required for replies in Slack
    my $thread_ts =
         $args->{thread_ts};

    my $json_attach = $args->{attachments}
      || die "Failed to postMessage: no attachment is provided\n";

    my $url = URI->new( $self->web_api_url . 'chat.postMessage' );

    my %params = (
        'token'       => $self->api_token,
        'channel'     => $channel,
        'attachments' => $json_attach,
        'as_user'     => 'true'
    );
    if ($thread_ts) {
      $params{thread_ts}=$thread_ts;
    }
    $url->query_form(%params);

    my $response      = $self->get_with_retries($url);
    my $json_contents = JSON::XS->new->utf8->decode( $response->content );

    return $json_contents;

}

sub chat_updateMessage {
    my $self = shift;
    my $args = shift;

    my $ts = $args->{ts} || die "Failed to updateMessage: ts is required\n";
    my $channel = $args->{channel}
      || die "Failed to updateMessage: channel is required\n";
    my $text = $args->{text};
    my $json_attach = $args->{attachments}
      || die "Failed to updateMessage: no attachment is provided\n";

    my $url = URI->new( $self->web_api_url . 'chat.update' );
    $url->query_form(
        'token'       => $self->api_token,
        'ts'          => $ts,
        'channel'     => $channel,
        'text'        => $text,
        'attachments' => $json_attach

    );

    my $response      = $self->get_with_retries($url);
    my $json_contents = JSON::XS->new->utf8->decode( $response->content );

    return $json_contents;

}

sub chat_deleteMessage {
    my $self = shift;
    my $args = shift;

    my $ts = $args->{ts} || die "Failed to deleteMessage: ts is required\n";
    my $channel = $args->{channel}
      || die "Failed to deleteMessage: channel is required\n";

    my $url = URI->new( $self->web_api_url . 'chat.delete' );
    $url->query_form(
        'token'   => $self->api_token,
        'ts'      => $ts,
        'channel' => $channel
    );

    my $response      = $self->get_with_retries($url);
    my $json_contents = JSON::XS->new->utf8->decode( $response->content );

    return $json_contents;

}


sub check_slack_response {
    my $self     = shift;
    my $response = shift;

    $self->last_err('') if $self->last_err ne '';    #delete prev error
	
    if ( !$response->is_success ) {
        die "Error: ", $response->status_line . "\n";
    }
	
    my $json_resp = JSON::XS->new->utf8->decode( $response->content );
	print "Slack response is:\n".$response->content."\n" if $self->debug;
    if ( !$json_resp->{ok} ) {
        if ( $json_resp->{error} eq 'message_not_found' ) {
            $self->last_err('message_not_found');
            return 1;
        }

        die "Error " . $json_resp->{error} . "\n";
    }
    else {
        carp "Warning " . $json_resp->{warning} if $json_resp->{warning};
        return 1;
    }

}

#helpers
sub store_message {
    my $eventid      = shift;
    my $message      = shift;
    my $storage_file = STORAGEFILE;
    my ( $stored, $to_store );

    $to_store = {
        ts      => $message->{ts},
        channel => $message->{channel}
    };
    

    if ( -f $storage_file ) {
        $stored = lock_retrieve $storage_file;
        
        push @{$stored->{$eventid}},$to_store;
        lock_store $stored, $storage_file;
    }
    else {

        #first time file creation, apply proper file permissions and store only single event
        lock_store {$eventid=>[
            $to_store
        ]}, $storage_file;
        chmod 0666, $storage_file;
    }

}

sub retrieve_from_store {
    my $eventid      = shift;
    my $delete       = shift || 0;
    my $storage_file = STORAGEFILE;
    my $stored;
    my $message_to_delete;


    if ( -f $storage_file ) {

        $stored = lock_retrieve $storage_file;

        if ( $message_to_delete = $stored->{$eventid} ) {
            delete $stored->{$eventid} if $delete;
            lock_store $stored, $storage_file;
        }
    }

    return $message_to_delete;

}

sub validate_slack_channel {
    my $slack_channel = shift;
    if ( $slack_channel =~ /^[#@].+/ ) {
        return $slack_channel;
    }
    else {
        die "Slack channel $slack_channel is neither channel or username.\n";
    }
}

=create_json_if_plain
$contents must be already utf8 decoded if non ASCII is present
like utf8::decode( $contents );
=cut

sub create_json_if_plain {
    my $self    = shift;
    my $contents = shift;
    my $json_hash;
    my $json_attach;
    eval {    #check if already JSON:
    
        my $message = $self->zbx_macro_to_json($contents->{message});
        $json_hash = JSON::XS->new->decode( $message );

    };
    if ($@) {
        print "message is not JSON, going to proceed as with regular text\n" if $self->{debug};
        $json_attach = create_json_attach_only($contents);
        return $json_attach;
    }
    else {
        print "message is JSON, going to proceed as with JSON attachment\n" if $self->{debug};
        if (   not defined( $json_hash->{color} )
            and exists( $contents->{color} ) )
        {

            print "Adding color to the attachment...\n";
            $json_hash->{color} = $contents->{color};

        }
        $json_attach = JSON::XS->new->utf8->encode( [$json_hash] );
        return $json_attach;
    }
}

sub create_json_attach_only {
    my $contents_ref = shift;
    return JSON::XS->new->utf8->encode(
        [
            {
                title    => $contents_ref->{subject},
                fallback => $contents_ref->{subject},
                text     => $contents_ref->{message},
                color    => $contents_ref->{color}
            }
        ]
    );
}


sub choose_color {
    
    my $contents = shift;
    my $color;
    if ($contents->{status} eq 'OK') { return '#CCFFCC'; }
    elsif ($contents->{severity} eq 'Not classified') {return '#DBDBDB';}
    elsif ($contents->{severity} eq 'Information') {return '#33CCFF';}
    elsif ($contents->{severity} eq 'Warning') {return '#FFFFCC';}
    elsif ($contents->{severity} eq 'Average') {return '#FFCCCC';}
    elsif ($contents->{severity} eq 'High') {return '#FF9999';}
    elsif ($contents->{severity} eq 'Disaster') {return '#FF6666';}
    else {return '#DBDBDB';}

}



sub get_with_retries {
    my $self          = shift;
    my $url           = shift;
    my $retry_counter = RETRY_DEFAULT;
    my $retry_after   = RETRY_WAIT_SECS;
    my $response;
    my $ua = LWP::UserAgent->new();

    if ( defined( $self->mock_url ) ) { $url = $self->mock_url; } #mock replace:
    $ua->env_proxy;
    $ua->show_progress(1) if $self->debug;

  ATTEMPT: {

        $response = $ua->get($url);

        if ( $response->is_success ) {

            #Check the status of the notification submission.

            $self->check_slack_response($response);
            print "Slack response OK.\n";
            return $response;

        }
        else {
            if ( $response->code == HTTP_TOO_MANY_REQUESTS ) {
                if ( defined( $response->header('Retry-After') )
                    and $response->header('Retry-After') > 0 )
                {
                    $retry_after = $response->header('Retry-After');
                }

                print $response->status_line . q{ }
                  . "Will try again in $retry_after seconds\n";

                sleep $retry_after;

                if ( $retry_counter < 1 ) {
                    die "Too many retries, unable to send message: ${ \$response->status_line } \n";
                }

                $retry_counter--;
                redo ATTEMPT;
            }
            else {
                die "Slack connection failed! ${ \$response->status_line } \n";
            }
        }
    }

}




sub DESTROY { }

1;
