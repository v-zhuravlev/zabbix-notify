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



my $mock_url="http://www.mocky.io/v2/5703a3f1270000e71f06afa1";
=mock for chat.postMessage
OK response parse
like this:
{
  "ok": true,
  "channel": "D0FJXP7L0",
  "ts": "1459856086.000002",
  "message": {
    "text": "Hello world",
    "username": "bot",
    "type": "message",
    "subtype": "bot_message",
    "ts": "1459856086.000002"
  }
}
=cut 
$slack_bot->mock_url($mock_url);
my $response = $slack_bot->chat_postMessage( {channel=> 'channel', attachments=> {} });
ok($response->{ts} eq '1459856086.000002', 'Check ts in response');
ok($response->{ok} , 'Check ok in response');
ok($response->{channel} eq 'D0FJXP7L0', 'Check channel in response');


=mock for channel not found
HTTP 200 OK
{
  "ok": false,
  "error": "channel_not_found"
}
=cut
$mock_url = 'http://www.mocky.io/v2/5703b37a270000582106afc0';
$slack_bot->mock_url($mock_url);
throws_ok { $slack_bot->chat_postMessage( {channel=> 'channel', attachments=> {} }) } '/Error channel_not_found/', 'check wrong channel';



=mock for message_not_found (in update or delete)
http://www.mocky.io/v2/5703b6d52700009b2106afc4
HTTP 200 OK
{
  "ok": false,
  "error": "message_not_found"
}
=cut
$mock_url = 'http://www.mocky.io/v2/5703b6d52700009b2106afc4';
$slack_bot->mock_url($mock_url);
lives_ok { $slack_bot->chat_postMessage( {channel=> 'channel',attachments=> {} }) } 'check message_not_found';





=mock 429
Mock that simulates HTTP 429 response with Header Retry-After:10 
see https://api.slack.com/docs/rate-limits
=cut
my $mock_429 = 'http://www.mocky.io/v2/57037d9d270000811b06af54';
$slack_bot->mock_url($mock_429);
throws_ok { $slack_bot->get_with_retries($mock_429) } '/429 Too Many Requests/', 'get_with_retries(429 LINK)';



=mock 429 no header
Mock that simulates HTTP 429 response without Header Retry-After
see https://api.slack.com/docs/rate-limits
=cut
$slack_bot->mock_url($mock_429);
$mock_429 = 'http://www.mocky.io/v2/57038de22700003a1d06af7a';
throws_ok { $slack_bot->get_with_retries($mock_429) } '/429 Too Many Requests/', 'get_with_retries(429 LINK)';



done_testing();