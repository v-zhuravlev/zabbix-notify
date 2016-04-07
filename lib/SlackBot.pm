package SlackBot;
use strict;
our $VERSION = '0.2';

use LWP;
use URI;
use Carp;
use JSON::XS;
use Data::Dumper;
use Storable qw(lock_store lock_retrieve);
use vars qw ($AUTOLOAD);

use constant {
    HTTP_TOO_MANY_REQUESTS => 429,
    RETRY_DEFAULT          => 2,
    RETRY_WAIT_SECS        => 5,
    CLEAR_ALARM_AFTER_SECS => 10,
    STORAGEFILE => '/var/tmp/zbx-slack-temp-storage',
};


sub AUTOLOAD {
   my $self = shift;
   my $type = ref ($self) || croak "$self is not an object";
   my $field = $AUTOLOAD;
   $field =~ s/.*://;
   unless (exists $self->{$field})
   {
      croak "$field does not exist in object/class $type";
   }
   if (@_)
   {
      return $self->{$field} = shift;
   }
   else
   {
      return $self->{$field};
   }
}



sub new {
    my $class       = shift;
    my $args        = shift;
    
    
    my $web_api_url = $args->{web_api_url} || 'https://slack.com/api/';
    my $api_token   = $args->{api_token}
      || croak " Failed to create Slack bot - No token provided";
    my $debug = $args->{debug} || 0;
    my $channel = $args->{channel};

    my $username = $args->{username};
    
    my $self = bless {
        api_token   => $api_token,
        web_api_url => $web_api_url,
        debug       => $debug,
        username    => $username,
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
    my $contents = shift
      || die "No contents provided to post into Slack!\n";

    my $json_attach = create_json_if_plain($contents);
    if (    $contents->{status} eq 'OK'
        and $contents->{mode} eq 'alarm'
        and defined( $contents->{eventid} ) )
    {
        print "Alarm recovery message!\n";

        my $mes_to_replace;

        if ( $mes_to_replace = retrieve_from_store( $contents->{eventid} ) )
        {
            print Dumper $mes_to_replace if $self->debug;
            $self->chat_updateMessage(
                {
                    text        => 'CLEARED',
                    attachments => $json_attach,
                    ts          => $mes_to_replace->{'ts'},
                    channel     => $mes_to_replace->{'channel'}
                }
            );
        }
        
        if (!$mes_to_replace or $self->last_err eq 'message_not_found') {

        #post the recovery then
            print "No messages found to be deleted\n";

            my $message =
              $self->chat_postMessage( { attachments => $json_attach } );
            $mes_to_replace = {
                ts      => $message->{'ts'},
                channel => $message->{'channel'}
            };
        }

        sleep CLEAR_ALARM_AFTER_SECS;

        $self->chat_deleteMessage(
            {
                ts      => $mes_to_replace->{'ts'},
                channel => $mes_to_replace->{'channel'}
            }
        );

    }

    else {
        print "Alarm message or plain event message!\n";
        my $message = $self->chat_postMessage(
            { attachments => $json_attach } );
        if ( $contents->{mode} eq 'alarm' ) {
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
    my $username = $args->{username} || $self->username;
      
    my $json_attach = $args->{attachments}
      || die "Failed to postMessage: no attachment is provided\n";

    my $url = URI->new( $self->web_api_url . 'chat.postMessage' );
    my %form_params = (
        'token'       => $self->api_token,
        'channel'     => $channel,
        'attachments' => $json_attach,
        'as_user'     => 'true',);
    
    if ($username) {
    %form_params = (%form_params, (
        'username'    => $username,
        'as_user'     => 'false',)
        );
    }
          
    $url->query_form(%form_params);

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
    my $text = $args->{text}
      || die "Failed to updateMessage: no text is provided\n";
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

sub search_message {

    my $self = shift;
    my $args = shift;

    my $query = $args->{query}
      || die "Failed to search for message: please provide a query\n";

    my $url = URI->new( $self->web_api_url . 'search.messages' );
    $url->query_form(
        'token'    => $self->api_token,
        'query'    => q{"} . $query . q{"},
        'sort'     => 'timestamp',
        'sort_dir' => 'desc'
    );

    my @resp;    #array to store messages ids
    my $response = $self->get_with_retries($url);
    my $json_resp =
      JSON::XS->new->utf8->decode( $response->content )->{'messages'}
      ->{'matches'};

    foreach my $message ( @{$json_resp} ) {

        push @resp,
          {
            'ts'      => $message->{'ts'},
            'channel' => $message->{'channel'}->{'id'}
          };
    }

    return @resp;

}


sub check_slack_response {  
    my $self    = shift;
    my $response = shift;
    
    $self->last_err('') if $self->last_err ne ''; #delete prev error
    
    if ( !$response->is_success ) {
        die "Error: ", $response->status_line."\n";
        return 0;
    }
    my $json_resp = JSON::XS->new->utf8->decode( $response->content );
    if ( !$json_resp->{ok} ) {
        if ($json_resp->{error} eq 'message_not_found'){
            $self->last_err('message_not_found');
            return 1;
        }
        
        die "Error " . $json_resp->{error}. "\n";
        return 0;
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
    my ($stored,$to_store);
    
    $to_store->{$eventid} = {
        ts      => $message->{ts},
        channel => $message->{channel}
    };
    
    if ( -f $storage_file ) {
        $stored = lock_retrieve $storage_file;
        lock_store { %$stored, %$to_store } , $storage_file;
    }
    else {
        #first time file creation, apply proper file permissions and store only single event
        lock_store $to_store, $storage_file;
        chmod 0666, $storage_file;
    }
    

}

sub retrieve_from_store {
    my $eventid      = shift;
    my $storage_file = STORAGEFILE;
    my $stored;
    my $message_to_delete;

    if ( -f $storage_file ) {

        $stored = lock_retrieve $storage_file;

        if ( $message_to_delete = delete $stored->{$eventid} ) {

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
        die
          "Slack channel $slack_channel is neither channel or username.\n";
    }
}


=create_json_if_plain
$contents must be already utf8 decoded if non ASCII is present
like utf8::decode( $contents );
=cut
sub create_json_if_plain {
    my $contents = shift;
    my $json_hash;
    my $json_attach;
    eval {    #check if already JSON:
        $json_hash = JSON::XS->new->decode( $contents->{message} );
    };
    if ($@) {
        print
"message is not JSON, going to proceed as with regular text\n";
        $json_attach = create_json_attach_only($contents);
        return $json_attach;
    }
    else {
        print
"message is JSON, going to proceed as with JSON attachment\n";
        if (   !defined( $json_hash->{color} )
            and exists( $contents->{color} ) )
        {

            print "Adding color to the attachment...\n";
            $json_hash->{color} = $contents->{color};

        }
        $json_attach = JSON::XS->new->encode( [$json_hash] );
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

sub get_with_retries {
    my $self          = shift;
    my $url           = shift;
    my $retry_counter = RETRY_DEFAULT;
    my $retry_after   = RETRY_WAIT_SECS;
    my $response;
    my $ua      = LWP::UserAgent->new();
    
    
    
    if ( defined($self->mock_url) ) { $url = $self->mock_url; }#mock replace: 
    
    $ua->show_progress( 1 ) if $self->debug;
    $response = $ua->get($url);
    
    
    
 
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
                if ( defined($response->header('Retry-After')) and $response->header('Retry-After') > 0 ) {
                    $retry_after = $response->header('Retry-After');
                }

                print $response->status_line . q{ }
                  . "Will try again in $retry_after seconds\n";

                sleep $retry_after;

                
                if ($retry_counter < 1) {die "Too many retries, unable to send message: ${ \$response->status_line } \n";}
                
                $retry_counter--;
                redo ATTEMPT;
            }
            else {
                
                die "Slack connection failed! ${ \$response->status_line } \n";
            }
        }
    }

}

sub DESTROY {}

1;