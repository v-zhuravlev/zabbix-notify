# -*- perl -*-
# t/002_slack_mocks.t - check module loading and create testing directory
use strict;
use warnings;
use Test::More;

BEGIN {
    eval "use Test::Exception";
    plan skip_all => "Test::Exception needed" if $@;
}

# ... tests that need Test::Exception ...
BEGIN { use_ok( 'SlackBot' ); }
use SlackBot; 
my $random_key = 'xoxb-30461853043-mQE7IGah4bGeC15T5gua4IzD';
my $slack_bot = SlackBot->new( { api_token => $random_key , debug => 1} );
ok( defined($slack_bot) && ref $slack_bot eq 'SlackBot',     'new() works' );

=mock 429
Mock that simulates HTTP 429 response with Header Retry-After:10 
see https://api.slack.com/docs/rate-limits
=cut
my $mock_429 = 'http://www.mocky.io/v2/57037d9d270000811b06af54';
throws_ok { $slack_bot->get_with_retries($mock_429) } '/429 Too Many Requests/', 'get_with_retries(429 LINK)';
=mock 429 no header
Mock that simulates HTTP 429 response without Header Retry-After
see https://api.slack.com/docs/rate-limits
=cut
$mock_429 = 'http://www.mocky.io/v2/57038de22700003a1d06af7a';
throws_ok { $slack_bot->get_with_retries($mock_429) } '/429 Too Many Requests/', 'get_with_retries(429 LINK)';


done_testing();