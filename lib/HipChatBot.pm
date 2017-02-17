package HipChatBot;
use strict;
use warnings;
our $VERSION = '0.7.1';
use parent 'ZabbixNotify';
use LWP;
use URI;
use Carp;
use JSON::XS;
use Data::Dumper;
use English '-no_match_vars';

use constant { ## no critic(ProhibitConstantPragma)
    MAX_HIPCHAT_ROOM_ID_LENGTH => 100,
    MAX_HIPCHAT_MESSAGE_LENGTH => 10000,
    MAX_HIPCHAT_FROM_LENGTH =>  64,
    HTTP_TOO_MANY_REQUESTS => 429,
    RETRY_DEFAULT          => 2,
    RETRY_WAIT_SECS        => 5,
};



sub new {
    my $class = shift;
    my $args  = shift;

    my $debug = $args->{debug} || 0;
    my $api_token = $args->{api_token}
        || croak " Failed to create HipChat bot - No token provided\n";
    my $web_api_url = 'https://api.hipchat.com';

    my $self = bless {
        api_token   => $api_token,
        web_api_url => $web_api_url,
        debug       => $debug,
        room     => undef,
        last_err    => '',
        mock_url    => undef
    }, $class;
      
      if (defined $args->{web_api_url}) {
        $self->web_api_url($args->{web_api_url});
      }
      if (defined $args->{room}) {
        $self->room($args->{room});
      }
  
      return $self;
  }


sub room {
    my $self = shift;
    if (@_) {
        my $room = shift;
        if ( not validate_hipchat_room_length($room) ) {
            die "Room $room is wrong. Exiting...\n";
        }
        return $self->{room} = $room;
    }
    else {
        return $self->{room};
    }
}


sub web_api_url {
    my $self = shift;
    if (@_) {
        my $web_api_url = shift;
        if ( not validate_hipchat_url($web_api_url) ) {
            die "HipChat URL $web_api_url is not valid.\n";
    }
        return $self->{web_api_url} = $web_api_url;
    }
    else {
        return $self->{web_api_url};
    }
}


sub post_message {
    my $self     = shift;
    my $contents = shift
      || die "No contents provided to post into Hipchat!\n";

    $contents->{color} = choose_color($contents);
    
    my $json_content = $self->create_json_if_plain($contents);
    
    print Dumper $json_content if $self->debug;
    $self->room_notification($json_content);

}


sub room_notification {
    my $self = shift;
    my $json = shift || die "Failed to send notification: json is required\n";;
    
    my $room = $self->room
      || die "Failed to send notification: room is required\n";
    
    my $url =
      $self->web_api_url."\/v2\/room/".$room."/notification?auth_token=".$self->api_token;
    


    $self->post_with_retries($url,$json);

      
}



=create_json_if_plain
$contents must be already utf8 decoded if non ASCII is present
like utf8::decode( $contents );
=cut

sub create_json_if_plain {
    my $self    =shift;
    my $contents = shift;
    my $json_hash;
    my $json_attach;
    eval {    #check if already JSON:
        
        my $message = $self->zbx_macro_to_json($contents->{message});
        $json_hash = JSON::XS->new->decode( $message );

    };
    if ($@) {
        print "message is not JSON, going to proceed as with regular text\n";
        $json_attach = create_json($contents);
        return $json_attach;
    }
    else {
        print "message is JSON, going to proceed as with JSON attachment\n";
        if (   not defined( $json_hash->{color} )
            and exists( $contents->{color} ) )
        {

            print "Adding color to the attachment...\n";
            $json_hash->{color} = $contents->{color};

        }
        $json_attach = JSON::XS->new->utf8->encode( $json_hash );
        return $json_attach;
    }
}

sub create_json {
    my $contents = shift;
    
    $contents->{message} = $contents->{subject} . "\n" . $contents->{message};
    
    if ( not validate_hipchat_message_length( $contents->{message} ) ) {
        warn "Message is too long. Have to cut it down\n";
        $contents->{message} = substr $contents->{message}, 0, MAX_HIPCHAT_MESSAGE_LENGTH;
    }


    my $json_hash =      {
            color          => $contents->{color},
            message        => $contents->{message},
            message_format => $contents->{hipchat}->{message_format},
            notify         => $contents->{hipchat}->{notify},
        };
    if (defined($contents->{hipchat}->{from})) {
        if ( not validate_hipchat_from_length( $contents->{hipchat}->{from} ) ) {
            warn "'from' is too long. Have to cut it down\n";
            $contents->{hipchat}->{from} = substr $contents->{hipchat}->{from}, 0, MAX_HIPCHAT_FROM_LENGTH;
        }
        $json_hash->{from}=$contents->{hipchat}->{from};
    }
    
    
    return JSON::XS->new->utf8->encode($json_hash);

}

sub choose_color {
    
    my $contents = shift;
    my $color;
    if ($contents->{status} eq 'OK') { return 'green'; }
    elsif ($contents->{severity} eq 'Not classified') {return 'gray';}
    elsif ($contents->{severity} eq 'Information') {return 'green';}
    elsif ($contents->{severity} eq 'Warning') {return 'yellow';}
    elsif ($contents->{severity} eq 'Average') {return 'yellow';}
    elsif ($contents->{severity} eq 'High') {return 'red';}
    elsif ($contents->{severity} eq 'Disaster') {return 'red';}
    else {return 'gray';}
    
}


    

sub post_with_retries {
    my $self          = shift;
    my $url           = shift;
    my $json_text     = shift;
    my $retry_counter = RETRY_DEFAULT;
    my $retry_after   = RETRY_WAIT_SECS;
    my $response;
    my $ua = LWP::UserAgent->new();

    if ( defined( $self->mock_url ) ) { $url = $self->mock_url; } #mock replace:
    $ua->env_proxy;
    $ua->show_progress(1) if $self->debug;

  ATTEMPT: {

        $response = $ua->post(
            $url,
            'Content-Type' => 'application/json',
            Content        => $json_text
        );

        if ( $response->is_success ) {

            #Check the status of the notification submission.

            #$self->check_slack_response($response);
            print "HipChat response OK.\n";
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
                    decode_and_print_hipchat_bad_response( $response->content );
                    die
"Too many retries, unable to send message: ${ \$response->status_line } \n";
                }

                $retry_counter--;
                redo ATTEMPT;
            }
            else {
                decode_and_print_hipchat_bad_response( $response->content );
                die "HipChat connection failed! ${ \$response->status_line } \n";
            }
        }
    }

}

#helpers
sub validate_hipchat_room_length {
    my $hipchat_room = shift;
    if ( length $hipchat_room <= MAX_HIPCHAT_ROOM_ID_LENGTH ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub validate_hipchat_url {
    my $hipchat_url = shift;
    if ( $hipchat_url =~ /https: \/ \/ /x ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub validate_hipchat_message_length {
    my $hipchat_message = shift;
    if ( length $hipchat_message <= MAX_HIPCHAT_MESSAGE_LENGTH ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub validate_hipchat_from_length {
    my $hipchat_from = shift;
    if ( length $hipchat_from <= MAX_HIPCHAT_FROM_LENGTH ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub decode_and_print_hipchat_bad_response {

    # example of what might be returned
    #{
    #  "error": {
    #  "code": 404,
    #  "message": "Room not found",
    #  "type": "Not Found"
    # }
    # }

    my $json_response;
    eval { $json_response = JSON::XS->new->decode(shift) };
    if ( !$EVAL_ERROR ) {
        print $json_response->{error}->{message} . "\n" if exists $json_response->{error}->{message};
    }
    return;
}





sub DESTROY { }

1;
