package PagerDutyBot;
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
    HTTP_TOO_MANY_REQUESTS => 429,
    RETRY_DEFAULT          => 2,
    RETRY_WAIT_SECS        => 5,
};

sub new {
    my $class = shift;
    my $args  = shift;

    my $debug = $args->{debug} || 0;
    my $api_token = $args->{api_token}
        || croak " Failed to create PagerDuty bot - No Service key provided\n";
    die "Service key provided is wrong. Should be 32 characters\n"
      unless $args->{api_token} =~ m/^[A-Za-z0-9_]{32}$/;

    my $self = bless {
        api_token   => $api_token,
        debug       => $debug,
        last_err    => '',
        mock_url    => undef
    }, $class;
      
      return $self;
  }



sub post_message {
    my $self     = shift;
    my $contents = shift
      || die "No contents provided to post into PagerDuty!\n";

    
    my $json_content = $self->create_json_if_plain($contents);
    
    print Dumper $json_content if $self->debug;
    $self->create_event($json_content);

}


sub create_event {
    my $self = shift;
    my $json = shift || die "Failed to send notification: room is required\n";;
    
   
    my $url = 'https://events.pagerduty.com/generic/2010-04-15/create_event.json';
    

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
        $json_attach = $self->create_json($contents);
        return $json_attach;
    }
    else {
        print "message is JSON, going to proceed as with JSON attachment\n";
        if (   not defined( $json_hash->{service_key} )
            and exists( $self->{api_token} ) )
        {

            print "Adding service_key to the JSON payload...\n";
            $json_hash->{service_key} = $self->{api_token};

        }
        $json_attach = JSON::XS->new->utf8->encode( $json_hash );
        return $json_attach;
    }
}

sub create_json {
    my $self =  shift;
    my $contents_ref = shift;

    my $json_text = {
        service_key  => $self->{api_token},
        incident_key => $contents_ref->{eventid},
    };
    
    if ($contents_ref->{status} eq 'PROBLEM') {
        $json_text->{event_type} = 'trigger';
        
        #foreach ( keys %{ $contents_ref->{details} } ) {
        #    $json_text->{details}->{$_} = $contents_ref->{details}->{$_};
        #}
        
        $json_text->{description} = $contents_ref->{subject};
        $json_text->{details} = $contents_ref->{message};
            
    }
    elsif ($contents_ref->{status} eq 'OK') {
            $json_text->{event_type} = 'resolve';
    }
    else {
        die "Unable to detect event_type\n";
    }
    
    
    if (   defined $contents_ref->{pagerduty}->{client_url}
        and defined $contents_ref->{pagerduty}->{client} )
    {
        $json_text->{client_url} = $contents_ref->{pagerduty}->{client_url};
        $json_text->{client}     = $contents_ref->{pagerduty}->{client};
    }
    
    return JSON::XS->new->utf8->encode($json_text);
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
            print "PagerDuty notification posted successfully.\n";
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
                    decode_and_print_pd_bad_response( $response->content );
                    die
"Too many retries, unable to send message: ${ \$response->status_line } \n";
                }

                $retry_counter--;
                redo ATTEMPT;
            }
            else {
                decode_and_print_pd_bad_response( $response->content );
                die "PagerDuty connection failed! ${ \$response->status_line } \n";
            }
        }
    }

}

#helpers
sub validate_pd_url {
    my $pd_url = shift;
    if ( $pd_url =~ /https: \/ \/ /x ) {
        return 1;
    }
    else {
        return 0;
    }
}



sub decode_and_print_pd_bad_response {

    # example of what might be returned
    #{"status":"invalid event",
    #"message":"Event object is invalid",
    #"errors":["incident_key is required for resolve events"]}
    my $json_response;
    eval { $json_response = JSON::XS->new->decode(shift) };
    if ( !$EVAL_ERROR ) {
        print $json_response->{status} .  "\n" if exists $json_response->{status};
        print $json_response->{message} . "\n" if exists $json_response->{message};
        if ( exists $json_response->{errors} ) {
            foreach ( @{ $json_response->{errors} } ) { print "$_\n"; }
        }
    }
    return;
}


sub DESTROY { }

1;
