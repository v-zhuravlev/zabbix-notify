# zabbix-notify
[![Build Status](https://travis-ci.org/v-zhuravlev/zabbix-notify.svg?branch=master)](https://travis-ci.org/v-zhuravlev/zabbix-notify)  
Notify alarms from Zabbix 3.x to Slack, HipChat and PagerDuty  

# About
This guide provides step-by-step guide how to install and use scripts to send notifications from Zabbix to popular collaborations platforms: **HipChat** (Deprecated), **Slack** and Incident Management system **PagerDuty**.
Here is the idea in brief:

- Install scripts on Zabbix Server
- In HipChat, Slack or PagerDuty generate access key for Zabbix
- In Zabbix setup new Media Type, Actions and assign new media type to new impersonal user
- Catch messages in Slack channel:

    ![image](https://cloud.githubusercontent.com/assets/14870891/14309222/bc9f510e-fbe3-11e5-94ff-66a313b00874.png)
- HipChat room:

    ![image](https://cloud.githubusercontent.com/assets/14870891/14309233/c7aba6ba-fbe3-11e5-80a2-f42bc1abbb76.png)
- or PagerDuty Console:

    ![image](https://cloud.githubusercontent.com/assets/14870891/14309241/d13943e0-fbe3-11e5-8242-3292dd8a91d5.png)



## Features Include:  
**All:**

- All configuration is done in Zabbix web-interface (no config files anywhere)  
- UTF8 supported
- HTTPS/HTTP proxy supported (see how at the end)

**Slack:**

- Color coding events depending on Trigger Status and Severity  
- Recovery and acknowledgements from Zabbix will be posted as new messages (`--slack_mode=event`)
- Acknowledgements (Zabbix 3.4+) will be attached as replies to [Slack message thread](https://slackhq.com/threaded-messaging-comes-to-slack). Recovery message from Zabbix will update and then delete initial problem message as well as all acknowledgements. (`--slack_mode=alarm`) ![image](https://user-images.githubusercontent.com/14870891/44022922-b6c2d0cc-9ef1-11e8-86c6-f830b4b00010.png)
- Acknowledgements will be attached as replies to Slack message thread. Recovery message from Zabbix will update initial message. (`--slack_mode=alarm-no-delete`)
- JSON can be used to compose Slack messages. See Slack [message attachments](https://api.slack.com/docs/attachments)  

**HipChat:**

- Color coding events depending on Trigger Status and Severity
- HTML or plain text can be used to format HipChat messages.
- JSON can be used to compose messages. See HipChat [API](https://www.hipchat.com/docs/apiv2/method/send_room_notification)  

**PagerDuty:**

- Recovery message from Zabbix will resolve already created incident in PagerDuty  
- Acknowledgements will be added already created incidents
- JSON can be used to compose messages. See PagerDuty API  [here](https://developer.pagerduty.com/documentation/integration/events/trigger)  and [here](https://developer.pagerduty.com/documentation/integration/events/resolve)  


**There are limitations to note as well:**  

- Slack and HipChat can reject you messages if you are sending them too often (more then 1 per second). It can accept short bursts but If you continue to spam - you will be blocked for one minute or so. So use Acton Conditions wisely to avoid event storms.

## Zabbix Server preparations  
Start with installing the script to Zabbix Server.  
The script is written in Perl and you will need common modules in order to run it:  
```
LWP
JSON::XS
```
There are numerous ways to install them:  

| in Debian  | In Centos | using CPAN | using cpanm|  
|------------|-----------|------------|------------|  
|  `apt-get install libwww-perl libjson-xs-perl` | `yum install perl-JSON-XS perl-libwww-perl perl-LWP-Protocol-https perl-parent` | `PERL_MM_USE_DEFAULT=1 perl -MCPAN -e 'install Bundle::LWP'` and  `PERL_MM_USE_DEFAULT=1 perl -MCPAN -e 'install JSON::XS'` | `cpanm install LWP` and `cpanm install JSON::XS`|  

You may also might requireadditional modules to do `make test` and installation:

| in Debian  | In Centos | using CPAN | using cpanm|  
|------------|-----------|------------|------------|  
|  `apt-get install libtest-simple-perl libtest-most-perl` | `yum install perl-ExtUtils-MakeMaker perl-Test-Simple perl-Test-Exception` | `cpan install ExtUtils::MakeMaker` and  `PERL_MM_USE_DEFAULT=1 perl -MCPAN -e 'install Test::Simple'` and  `PERL_MM_USE_DEFAULT=1 perl -MCPAN -e 'install Test::Exception'` | `cpanm install ExtUtils::MakeMaker` and `cpanm install Test::Simple` and `cpanm install Test::Exception`|  

Once this is done, download tar and install it into the system:  
```
perl Makefile.PL INSTALLSITESCRIPT=/usr/local/share/zabbix/alertscripts
make test
make install
```
where INSTALLSITESCRIPT is your Zabbix's  alert script folder as defined in zabbix_server.conf.  

Please note that currently `make test` requires Internet connection to test with mocks :) So skip if you don't have one.  

# Slack Setup  
1. You have to have the [Bots app](https://slack.com/apps/A0F7YS25R-bots) installed.
1. Create a bot
![image](https://cloud.githubusercontent.com/assets/14870891/14309257/e962e660-fbe3-11e5-8ef1-6158342cdac9.png)  
1. Fill in the card:  
![image](https://cloud.githubusercontent.com/assets/14870891/14309488/6f80241e-fbe5-11e5-82c2-2c4fdf18eae1.png)  
1. Upload this icon for the bot, or choose another:  
![z_logo](https://cloud.githubusercontent.com/assets/14870891/14309527/bbcf9c00-fbe5-11e5-9849-d7bc1aae374f.png)
1. If you want the bot to broadcast to a channel, invite it to the channel, where you want it to post.
to do this in Slack channel type:  
```
/invite @zabbix_bot
```

## Test with Slack 
Once you have done the basic setup, go back to the terminal and test the script by running it under the zabbix user:

```
root#: sudo -u zabbix /bin/sh
cd /usr/local/share/zabbix/alertscripts
```

 
To ADD ALARM:

```
./zbx-notify @your_name_in_slack_here 'PROBLEM:myHOSTNAME Temperature Failure on DAE5S Bus 1 Enclosure 1' 'Host: myHOSTNAME \
Trigger: PROBLEM: myHOSTNAME Temperature Failure on DAE5S Bus 1 Enclosure 1: High \
Timestamp: 2016.03.14 11:57:10 YEKT eventid: 100502' --api_token=your_token_here --slack
```

To CLEAR ALARM RUN:

```
./zbx-notify @your_name_in_slack_here 'OK:myHOSTNAME Temperature Failure on DAE5S Bus 1 Enclosure 1' 'Host: myHOSTNAME \
Trigger: OK: myHOSTNAME Temperature Failure on DAE5S Bus 1 Enclosure 1: High \
Timestamp: 2016.03.14 11:57:10 YEKT eventid: 100502' --api_token=your_token_here --slack
```


## Zabbix Configuration (Slack)
Now all is left is to setup new Action and Media Type.

### Media type  
First go to **Administration -> Media Types**, press **Create media type**  
![image](https://cloud.githubusercontent.com/assets/14870891/14527463/ddb8a6c2-0252-11e6-9f24-97b80a01539b.png)  
Choose Type: *Script*  
Name: *Slack*  
Script name: *zbx-notify*  
Fill **Script parameters** in the following order  
1: `{ALERT.SENDTO}`  
2: `{ALERT.SUBJECT}`  
3: `{ALERT.MESSAGE}`  
4: `--api_token=you_token_here`  
5: `--slack`  
6: `--no-fork` (for Zabbix 3.4+ only)
Note that there should be no ticks or quotes after `--api-token=` only the key itself.  
You may provide additional params as well, by pressing **Add** and filling them in the form:  
`--param=value`  

Here is what you can setup for Slack:  

| Parameter        | Description                      | Default value  | Example value                           | JSON mode(see below)  |  
| ---------------- |:---------------------:|:--------------:|-----------------------------------------|----|  
| `api_token`        |  you bot api token (Mandatory)    | none           |`--api_token=xoxb-30461853043-mQE7IGah4bGeC15T5gua4IzK`|  Yes |  
| `slack_mode`        |  operation mode (`event`, `alarm`, `alarm-no-delete`)   | event           |`--slack_mode=event`|    Yes |
| `debug`        |  For providing debug output, useful when running from command line   |   none         |`--debug`|    Yes |
| `no-fork`          |  To prevent script from forking on posting to Slack. |   none         |`--no-fork`|    Yes |
| `no-ssl_verify_hostname`        |  To ignore SSL certificate validation failures.   |   none         |`--no-ssl_verify_hostname`|    Yes |

Press *Add* to finish media type creation.  

### User changes (for direct to user notifications)
If you want your users to be able to get direct notifications from the bot...

#### Setting up zabbix slack media for multiple users
1. Go to **Administration->Users**
1. Select a user
1. Select the **Media** tab
1. Click **Add**
1. Select **Type**: Slack
1. Fill in **Send to**: `@slackusername` (with the user's corresponding slack address)
1. Click Add
1. Click Update
1. Repeat for as many users as you want to preconfigure

#### Setting up zabbix slack media as a user
If your users want to make changes:

1. Click the profile icon (near the top right of a zabbix page)
1. Select the **Media** tab
1. If there's no Slack type already set up:
  1. Click **Add**
  1. Select **Type**: Slack
  1. Fill in **Send to**: `@slackusername` (with the user's corresponding slack address)
  1. Click Add
1. If there's already a Slack type, click the corresponding **Edit** action
  1. Update the **Send to** field with the appropriate `@slackusername` (with the user's corresponding slack address)
  1. Update **When active** as appropriate (see zabbix documentation)
  1. Update **Use if severity** as desired
  1. Click Update
1. Click Update

### User creation (For channel notifications)
As you finish with defining new Media Type for Slack proceed to next step and create impersonal user:

1. Go to **Administration->Users**
1. Click **Create user**:  
1. In **User** tab:
  1. **Alias**: Notification Agent  
  1. **Groups**: Make sure you add him proper Group Membership so this user has the rights to see new Events (and so notify on them).  
  1. **Password**: anything complex you like, you will never use it  
![image](https://cloud.githubusercontent.com/assets/14870891/14313150/9eacdc1a-fbf8-11e5-9bbd-6ed239d0c599.png)  
 
1. **In Media tab:**  
  1. Create New media:  
    1. **Type:** Slack  
    1. **Send to:** Place your Slack #channel name here for example #zabbix.  
![image](https://cloud.githubusercontent.com/assets/14870891/14527650/145abfac-0254-11e6-8875-ec42aff616b4.png)
 
### Action creation:

To Create a new action:

1. Go to **Configuration -> Action**
1. Choose **Event source: Triggers**
1. press **Create action**
1. that is to be sent to Slack.

Here is the example:  
In **Operations** tab:  
![image](https://user-images.githubusercontent.com/14870891/44031782-c9cd7a48-9f0d-11e8-9106-244059feb6dc.png)

Default subject: anything you like, but I recommend:
 
```
{TRIGGER.STATUS}:{HOSTNAME}:{TRIGGER.NAME}. 
```

Default message: anything you like.  

```
Host: {HOSTNAME}
Trigger: {STATUS}: {TRIGGER.NAME}: {TRIGGER.SEVERITY}
Timestamp: {EVENT.DATE} {EVENT.TIME}
{TRIGGER.COMMENT}
{TRIGGER.URL}
http://zabbix.local
Eventid: {EVENT.ID}
```

In **Recovery operations** tab:
Default subject: anything you like, but I recommend  

```
{TRIGGER.STATUS}:{HOSTNAME}:{TRIGGER.NAME}. 
```

Default message:  

```
Host: {HOSTNAME}
Trigger: {STATUS}: {TRIGGER.NAME}: {TRIGGER.SEVERITY}
Timestamp: {EVENT.RECOVERY.DATE} {EVENT.RECOVERY.TIME}
{TRIGGER.COMMENT}
{TRIGGER.URL}
http://zabbix.local
Eventid: {EVENT.ID}
```

In **Acknowledgement operations** (Zabbix 3.4+) tab:

```
{USER.FULLNAME} acknowledged problem at {ACK.DATE} {ACK.TIME} with the following message:
{ACK.MESSAGE}
Current problem status is {EVENT.STATUS}, Eventid: {EVENT.ID}
```

Note:  if you place Macros **{TRIGGER.SEVERITY}** and **{STATUS}** then your messages in Slack will be color coded.  
Note:  place line `Eventid: {EVENT.ID}` if you want to use Alarm mode in all messages, including Acknowledgements.     

As an alternative you can place JSON object here that would represent Slack [attachment:](https://api.slack.com/docs/attachments)  
![image](https://cloud.githubusercontent.com/assets/14870891/14406644/0c820002-feb6-11e5-98e0-6acadad8b7f1.png)  
Note though, that it is required to place all Zabbix MACROS in double brackets [[ ]], so they are properly transformed into JSON String.  
For TRIGGER transitioning to PROBLEM you might use:

```
{
            "fallback": "[[{HOST.NAME}:{TRIGGER.NAME}:{STATUS}]]",
            "pretext": "New Alarm",
            "author_name": "[[{HOST.NAME}]]",
            "title": "[[{TRIGGER.NAME}]]",
            "title_link": "http://zabbix/tr_events.php?triggerid={TRIGGER.ID}&eventid={EVENT.ID}",
            "text": "[[{TRIGGER.DESCRIPTION}]]",
            "fields": [
                {
                    "title": "Status",
                    "value": "{STATUS}",
                    "short": true
                },
                {
                    "title": "Severity",
                    "value": "{TRIGGER.SEVERITY}",
                    "short": true
                },
                {
                    "title": "Time",
                    "value": "{EVENT.DATE} {EVENT.TIME}",
                    "short": true
                },
                {
                    "title": "EventID",
                    "value": "eventid: {EVENT.ID}",
                    "short": true
                }
                
                
            ]
        }
```

And for Recovery:  

```
{
            "fallback": "[[{HOST.NAME}:{TRIGGER.NAME}:{STATUS}]]",
            "pretext": "Cleared",
            "author_name": "[[{HOST.NAME}]]",
            "title": "[[{TRIGGER.NAME}]]",
            "title_link": "http://zabbix/tr_events.php?triggerid={TRIGGER.ID}&eventid={EVENT.RECOVERY.ID}",
            "text": "[[{TRIGGER.DESCRIPTION}]]",
            "fields": [
                {
                    "title": "Status",
                    "value": "{STATUS}",
                    "short": true
                },
                {
                    "title": "Severity",
                    "value": "{TRIGGER.SEVERITY}",
                    "short": true
                },
                {
                    "title": "Time",
                    "value": "{EVENT.RECOVERY.DATE} {EVENT.RECOVERY.TIME}",
                    "short": true
                },
                {
                    "title": "EventID",
                    "value": "eventid: {EVENT.ID}",
                    "short": true
                },
                {
                    "title": "Event Acknowledgement history",
                    "value": "[[{EVENT.ACK.HISTORY}]]",
                    "short": false
                }, 
                {
                    "title": "Escalation history",
                    "value": "[[{ESC.HISTORY}]]",
                    "short": false
                }

                
                
            ]
        }
```
 
In **Condition** tab do not forget to include **Trigger value = Problem condition** (This option is removed in Zabbix 3.4). The rest depends on your needs.  
![image](https://cloud.githubusercontent.com/assets/14870891/14313939/2ae4e980-fbfd-11e5-96db-81325b6d40b0.png)
 
In **Operations** tab select Notification Agent as recipient of the message sent via Slack.  
![image](https://cloud.githubusercontent.com/assets/14870891/14314053/d123e30a-fbfd-11e5-8717-74113151b4da.png)  

More on Action configuration in Zabbix can be found  [here:](https://www.zabbix.com/documentation/3.0/manual/config/notifications/action)    

That it is it  

# Hipchat Setup
Moved here to  [wiki:](https://github.com/v-zhuravlev/zabbix-notify/wiki/Hipchat-Setup)

# PagerDuty Setup  
And *finally* PagerDuty. If your team doesn't have the account you can get it [here](https://signup.pagerduty.com/accounts/new)  

Once inside PagerDuty you will need to setup **Services** that will provide you with data. To do this go to **Configuration->Services**:  
![image](https://cloud.githubusercontent.com/assets/14870891/14526382/88ead7fc-024b-11e6-9025-999f6a477e00.png)

On the next page choose Zabbix from the list of services and choose a name for your Zabbix installation:
![image](https://cloud.githubusercontent.com/assets/14870891/14526388/954236a8-024b-11e6-84a6-189e527e01b5.png)
You will see Service key on the next page: save it somewhere as you will need this in Zabbix.

## Test with PagerDuty 
Once you have done the previous step, go back to console and test the script by running it under user Zabbix:

```
root#:su - zabbix
cd /usr/local/share/zabbix/alertscripts
```

To ADD ALARM:

```
./zbx-notify pagerduty 'PROBLEM:myHOSTNAME Temperature Failure on DAE5S Bus 1 Enclosure 1' \
'Host: myHOSTNAME \
Trigger: PROBLEM: myHOSTNAME Температуа Failure on DAE5S Bus 1 Enclosure 1: High \
Timestamp: 2016.03.14 11:57:10 eventid: 100502' \
--api_token=1baff6f955c040d795387e7ab9d62090 \
--pagerduty --no-fork
```

To RESOLVE IT:

```
./zbx-notify pagerduty 'OK:myHOSTNAME Temperature Failure on DAE5S Bus 1 Enclosure 1' \
'Host: myHOSTNAME \
Trigger: OK: myHOSTNAME Температуа Failure on DAE5S Bus 1 Enclosure 1: High \
Timestamp: 2016.03.14 11:57:10 eventid: 100502' \
--api_token=1baff6f955c040d795387e7ab9d62090 \
--pagerduty --no-fork
```


## Zabbix Configuration (PagerDuty)
Now all is left is to setup new Action and Media Type.  
### Media type  
First go to **Administration -> Media Types**, press **Create media type**  
![image](https://cloud.githubusercontent.com/assets/14870891/14527515/4040725c-0253-11e6-9a38-f529c9c7c38f.png)  
Choose Type: *Script*  
Name: *PagerDuty*  
Script name: *zbx-notify*  
Fill **Script parameters** in the following order  
1: `{ALERT.SENDTO}`  
2: `{ALERT.SUBJECT}`  
3: `{ALERT.MESSAGE}`  
4: `--api_token=you_token_here`  
5: `--pagerduty`  
6: `--no-fork` (for Zabbix 3.4+ only)
Note that there should be no ticks or quotes after `--api-token=` only the key itself.  
You may provide additional params as well, by pressing **Add** and filling them in the form:  
`--param=value`  

Here is what you can setup for PagerDuty:  

| Parameter        | Description                      | Default value  | Example value                           |  JSON mode(see below)  | 
| ---------------- |:---------------------:|:--------------:|-----------------------------------------|---|  
| api_token        |  your Service key(Mandatory)    | none           |--api_token=1baff6f955c040d795387e7ab9d62090| Yes |  
| pagerduty_client        |  Zabbix instance name(only works if both client and client_url are provided)   | none           |--pagerduty_client=Myzabbix |  Ignored |
| pagerduty_client_url        |  Zabbix instance name link   | none           | --pagerduty_client_url=http://zabbix.local |  Ignored |
| debug        |  For providing debug output, useful when running from command line   |   none         |--debug|  Yes |
| no-fork          |  To prevent script from forking on posting to Slack    |   none         |--no-fork|  Yes |
| no-ssl_verify_hostname        |  To ignore SSL certificate validation failures.   |   none         |--no-ssl_verify_hostname|    Yes |

Click *Add* to finish media type creation.  

### User creation
As you finish with defining new Media Type for PagerDuty proceed to next step and create impersonal user:  
Go to **Administration->Users**  Click **Create user**:  

**In User tab:**  
**Alias**: Notification Agent  
**Groups**: Make sure you add him proper Group Membership so this user has the rights to see new Events (and so notify on them).  
**Password**: anything complex you like, you will never use it  
![image](https://cloud.githubusercontent.com/assets/14870891/14313150/9eacdc1a-fbf8-11e5-9bbd-6ed239d0c599.png)  

**In Media tab:**  
Create New media:  
**Type:** PagerDuty  
**Send to:** PagerDuty  
![image](https://cloud.githubusercontent.com/assets/14870891/14527875/47ffeb06-0255-11e6-9611-22ca3dc38f5a.png)  

 
### Action creation:
Create new action (go to **Configuration -> Action** ,choose  **Event source: Triggers** Click **Create action**) that is to be send to PagerDuty.  
Here is the example:  
In **Action** tab:  
Default/recovery subject: anything you like, but I recommend  

```
{STATUS} : {HOSTNAME} : {TRIGGER.NAME}
```

Default message:  
anything you like, for example:  

```
{TRIGGER.DESCRIPTION}
Status: {STATUS}
Severity: {TRIGGER.SEVERITY}
Timestamp: {EVENT.DATE} {EVENT.TIME}
eventid: {EVENT.ID}
```

Recovery message:  

```
{TRIGGER.DESCRIPTION}
Status: {STATUS}
Severity: {TRIGGER.SEVERITY}
Timestamp: {EVENT.DATE} {EVENT.TIME}
eventid: {EVENT.ID}
Event Acknowledgement history: {EVENT.ACK.HISTORY}
Escalation history: {ESC.HISTORY}
```

As an alternative you can place JSON object here that would represent PagerDuty  
See PagerDuty API  [here](https://developer.pagerduty.com/documentation/integration/events/trigger)  and [here](https://developer.pagerduty.com/documentation/integration/events/resolve).  
Note though, that it is required to place all Zabbix MACROS in double brackets `[[` `]]`, so they are properly transformed into JSON String.  
For TRIGGER transitioning to PROBLEM you might use (Default Message):  

```
{    
      
      "incident_key": "{EVENT.ID}",
      "event_type": "trigger",
      "description": "[[{TRIGGER.NAME}]]",
      "client": "Zabbix Monitoring system",
      "client_url": "http://zabbix",
      "details": {
        "Status": "[[{STATUS}]]",
        "Timestamp": "[[{EVENT.DATE} {EVENT.TIME}]]",
        "Hostname": "[[{HOST.NAME}]]",
        "Severity": "[[{TRIGGER.SEVERITY}]]",
        "Description": "[[{TRIGGER.DESCRIPTION}]]",
        "IP": "[[{HOST.IP}]]"
      },
      "contexts":[ 
        {
          "type": "link",
          "href": "http://zabbix/tr_events.php?triggerid={TRIGGER.ID}&eventid={EVENT.ID}",
          "text": "View Event details in Zabbix"
        }
      ]
    }
```

And for Recovery:  

```
{
    "incident_key": "{EVENT.ID}",
    "event_type": "resolve",
    "description": "[[{TRIGGER.NAME}]]",
    "details": {
        "Status": "[[{STATUS}]]",
        "Timestamp": "[[{EVENT.RECOVERY.DATE} {EVENT.RECOVERY.TIME}]]",
        "Event Acknowledgement history: ": "[[{EVENT.ACK.HISTORY}]]",
        "Escalation history:": "[[{ESC.HISTORY}]]"
    }
}
```

**Note**: do not insert `"service_key": "key"` in JSON, it is appended automatically.  

![image](https://cloud.githubusercontent.com/assets/14870891/14530924/cf05cac2-0263-11e6-9aef-25ed525bb46e.png)  
 
 
In **Condition** tab do not forget to include **Trigger value = Problem condition** (This option is removed in Zabbix 3.4). The rest depends on your needs.  
![image](https://cloud.githubusercontent.com/assets/14870891/14313939/2ae4e980-fbfd-11e5-96db-81325b6d40b0.png)
 
In **Operations** tab select Notification Agent as recipient of the message sent via PagerDuty.  
![image](https://cloud.githubusercontent.com/assets/14870891/14532236/0ef4ea8c-0269-11e6-8315-a711dda53506.png)  

More on Action configuration in Zabbix can be found  [here:](https://www.zabbix.com/documentation/3.0/manual/config/notifications/action)    

# About using --no-fork

If you have Zabbix 3.4 or newer, it recommended to use --no-fork option from Zabbix. This will give you an ability to see [errors](https://www.zabbix.com/documentation/3.4/manual/introduction/whatsnew340#return_code_check_for_scripts_and_commands) in Zabbix if something goes wrong:
![image](https://user-images.githubusercontent.com/14870891/44034320-7e373f58-9f15-11e8-83f2-09016ec60d32.png)

 Just make sure you enabled [concurrent sessions](https://www.zabbix.com/documentation/3.4/manual/introduction/whatsnew340#parallel_processing_of_alerts) in Zabbix.  
Use --no-fork with care if you use Slack with --slack_mode=alarm, since script then sleeps for 30s before removing messages from Slack.



# Troubleshooting
In order to troubleshoot problems, try to send test message from the command line under user `zabbix`.  
Try using `--no-fork` and `--debug` command line switches

You may also want to increase the logging of alerter process to DEBUG for a while. 
(optional) If appropriate, decrease the level of logging of all zabbix processes to reduce the noise in the log file:

```
zabbix_server --runtime-control log_level_decrease
zabbix_server --runtime-control log_level_decrease
zabbix_server --runtime-control log_level_decrease
zabbix_server --runtime-control log_level_decrease
```

Then increase the logging of alerter process to DEBUG for a while: 

To do it run it as many times as required to reach DEBUG from your current level (4 times if your current log level is 0)

```
zabbix_server --runtime-control log_level_increase=alerter  
zabbix_server --runtime-control log_level_increase=alerter  
zabbix_server --runtime-control log_level_increase=alerter  
zabbix_server --runtime-control log_level_increase=alerter  
```

now tail you log to see what the problem might be:
`tail -f /var/log/zabbix-server/zabbix_server.log`  

## HTTP(S) Proxy  
If you need to use proxy to connect to services, make sure that environment variables 
`http_proxy` and `https_proxy` are set under user `zabbix`, for example:

```
export http_proxy=http://proxy_ip:3128/
export https_proxy=$http_proxy
```
