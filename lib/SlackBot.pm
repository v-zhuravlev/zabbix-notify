package SlackBot;
use strict;
our $VERSION = 0.1;

use subs 'channel';
use Class::Tiny qw( api_token web_api_url debug username channel);
use LWP;
use URI;
use Carp;
use JSON::XS;
use Data::Dumper;    #temp
                     #use Storable qw(lock_store lock_retrieve);
use Storable;
use File::Basename;

use constant {
    HTTP_TOO_MANY_REQUESTS => 429,
    RETRY_DEFAULT          => 2,
    RETRY_WAIT_SECS        => 5,

    #STORAGEFILE => 'zbx-slack-temp-storage'
    STORAGEFILE => '/var/tmp/zbx-slack-temp-storage',
};

sub BUILDARGS {
    my $class       = shift;
    my $args        = shift;
    my $web_api_url = $args->{web_api_url} || 'https://slack.com/api/';
    my $api_token   = $args->{api_token}
      || croak " Failed to create Slack bot - No token provided";
    my $debug = $args->{debug} || 0;
    my $channel = $args->{channel};

    my $username = $args->{username};
    return {
        api_token   => $api_token,
        web_api_url => $web_api_url,
        debug       => $debug,
        username    => $username,
        channel     => $channel,
    };
}

sub channel {
    my $self = shift;
    if (@_) {
        my $channel = shift;
        validate_slack_channel($channel)
          ;    #<----whats added to default get/set
        return $self->{channel} = $channel;
    }
    elsif ( exists $self->{channel} ) {
        return $self->{channel};
    }
    else {
        my $defaults =
          Class::Tiny->get_all_attribute_defaults_for( ref $self );
        return $self->{channel} = $defaults->{channel}->();
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

#my @resp = $self->search_message({query=>'eventid: '.$contents->{eventid}});

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
        else {    #post the recovery then
            print "No messages found to be deleted\n";

            my $message =
              $self->chat_postMessage( { attachments => $json_attach } );
            $mes_to_replace = {
                ts      => $message->{'ts'},
                channel => $message->{'channel'}
            };
        }

        sleep 5;

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
            { username => "Zabbix bot", attachments => $json_attach } );
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
    my $username =
         $args->{username}
      || $self->username
      || die "Failed to postMessage: username is required\n";
    my $json_attach = $args->{attachments}
      || die "Failed to postMessage: no attachment is provided\n";

    my $url = URI->new( $self->web_api_url . 'chat.postMessage' );
    $url->query_form(
        'token'       => $self->api_token,
        'channel'     => $channel,
        'username'    => $username,
        'as_user'     => 'true',
        'attachments' => $json_attach
    );

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

#helpers
sub check_slack_response {    #check for errors or warnings;

    my $response = shift;
    if ( !$response->is_success ) {
        croak "Error: ", $response->status_line unless $response->is_success;
        return 0;
    }
    my $json_resp = JSON::XS->new->utf8->decode( $response->content );
    if ( !$json_resp->{ok} ) {
        croak "Error " . $json_resp->{error} unless $json_resp->{ok};
        return 0;
    }
    else {
        carp "Warning " . $json_resp->{warning} if $json_resp->{warning};
        return 1;
    }
}

sub store_message {
    my $eventid      = shift;
    my $message      = shift;
    #my $storage_file = dirname(__FILE__) . '/' . STORAGEFILE;
    my $storage_file = STORAGEFILE;
    my $stored;

    if ( -f $storage_file ) {

        #$stored = lock_retrieve $storage_file;
        #$stored = retrieve $storage_file;
        $stored = retrieve STORAGEFILE;
    }

    $stored->{$eventid} = {
        ts      => $message->{ts},
        channel => $message->{channel}
    };

    #lock_store $stored, $storage_file;
    store $stored, $storage_file;

    #unlock($storage_file);

}

sub retrieve_from_store {
    my $eventid      = shift;
    my $storage_file = STORAGEFILE;
    my $stored;
    my $message_to_delete;

    if ( -f $storage_file ) {
        $stored = retrieve $storage_file;

        #$stored = lock_retrieve $storage_file;

        if ( $message_to_delete = delete $stored->{$eventid} ) {
            print $message_to_delete;

            print "What is left in storage: :";

            store $stored, $storage_file;

            #lock_store $stored, $storage_file;
        }
    }

    #unlock($storage_file);

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

sub create_json_if_plain {
    my $contents = shift;
    my $json_hash;
    my $json_attach;
    eval {    #check if already JSON:
        $json_hash = JSON::XS->new->utf8->decode( $contents->{message} );
    };
    if ($@) {
        print
"message is not a JSON, going to proceed as as with regular text\n";
        $json_attach = create_json_attach_only($contents);
        return $json_attach;
    }
    else {
        print
"message is in JSON, going to proceed as as with JSON attachment\n";
        if (   !defined( $json_hash->{color} )
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

sub get_with_retries {
    my $self          = shift;
    my $url           = shift;
    my $retry_counter = RETRY_DEFAULT;
    my $retry_after   = RETRY_WAIT_SECS;
    my $response;
    my $ua      = LWP::UserAgent->new();
    my $timeout = 3;

    print $url if ( $self->debug );
  ATTEMPT: {

        $response = $ua->get($url);
        check_slack_response($response);

        if ( $response->is_success ) {

            #Check the status of the notification submission.
            print "Slack was connected successfully.\n";
        }
        else {
            if ( $response->code == HTTP_TOO_MANY_REQUESTS ) {
                if ( $response->header('Retry-After') > 0 ) {
                    $retry_after = $response->header('Retry-After');
                }

                print $response->status_line . q{ }
                  . "Will try again in $retry_after seconds\n";

                sleep $retry_after;

                #decode_and_print_slack_bad_response( $response->content );
                die "Slack conn failed! ${ \$response->status_line } \n"
                  if $retry_counter < 1;
                $retry_counter--;
                redo ATTEMPT;
            }
            else {
                #decode_and_print_slack_bad_response( $response->content );
                die "Slack conn failed! ${ \$response->status_line } \n";
            }
        }
    }
    return $response;

}

1;