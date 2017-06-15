# zabbix-notify
[![Build Status](https://travis-ci.org/v-zhuravlev/zabbix-notify.svg?branch=master)](https://travis-ci.org/v-zhuravlev/zabbix-notify)  
Notify alarms from Zabbix 3.0 to Slack, HipChat and PagerDuty  

# About
This guide provides step-by-step guide how to install and use scripts to send notifications from Zabbix to popular collaborations platforms: **HipChat**, **Slack** and Incident Management system **PagerDuty**.
Here is the idea in brief:  
-	install scripts on Zabbix Server
-	in HipChat, Slack or PagerDuty generate access key for Zabbix
-	In Zabbix setup new Media Type, Actions and assign new media type to new impersonal user
-	Catch messages in Slack channel, HipChat room or PagerDuty Console:
![image](https://cloud.githubusercontent.com/assets/14870891/14309222/bc9f510e-fbe3-11e5-94ff-66a313b00874.png)  
![image](https://cloud.githubusercontent.com/assets/14870891/14309233/c7aba6ba-fbe3-11e5-80a2-f42bc1abbb76.png)  
![image](https://cloud.githubusercontent.com/assets/14870891/14309241/d13943e0-fbe3-11e5-8242-3292dd8a91d5.png)  



## Features Include:  
**All:**  
-	All configuration is done in Zabbix web-interface(no config files anywhere)  
-	UTF8 supported  
- HTTPS/HTTP proxy supported(see how at the end)  

**Slack:**  
-	Color coding events depending on Trigger Status and Severity  
-	Recovery message from Zabbix will be posted as new message (--slack_mode=event)  
-	Recovery message from Zabbix will update and then delete already posted message in Slack (--slack_mode=alarm)  
-	JSON can be used to compose Slack messages. See Slack [message attachments](https://api.slack.com/docs/attachments)  

**HipChat:**  
-	Color coding events depending on Trigger Status and Severity
-	HTML or plain text can be used to format HipChat messages.
-	JSON can be used to compose messages. See HipChat [API](https://www.hipchat.com/docs/apiv2/method/send_room_notification)  

**PagerDuty:**  
-	Recovery message from Zabbix will resolve already created incident in PagerDuty  
-	JSON can be used to compose messages. See PagerDuty API  [here](https://developer.pagerduty.com/documentation/integration/events/trigger)  and [here](https://developer.pagerduty.com/documentation/integration/events/resolve)  


**There are limitations to note as well:**  
-	Slack and HipChat can reject you messages if you are sending them too often (more then 1 per second). It can accept short bursts but If you continue to spam - you will be blocked for one minute or so. So use Acton Conditions wisely to avoid event storms.

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
|  `apt-get install libwww-perl libjson-xs-perl` | `yum install perl-JSON-XS perl-libwww-perl perl-LWP-Protocol-https` | `PERL_MM_USE_DEFAULT=1 perl -MCPAN -e 'install Bundle::LWP'` and  `PERL_MM_USE_DEFAULT=1 perl -MCPAN -e 'install JSON::XS` | `cpanm install LWP` and `cpanm install JSON::XS`|  


Once this is done, download tar and install it into the system:  
```
perl Makefile.PL INSTALLSITESCRIPT=/usr/local/share/zabbix/alertscripts
make test
make install
```
where INSTALLSITESCRIPT is your Zabbix's  alert script folder as defined in zabbix_server.conf.  

Please note that currently `make test` requires Internet connection to test with mocks :) So skip if you don't have one.  

# Slack Setup  
In Slack  you would have to create a bot
![image](https://cloud.githubusercontent.com/assets/14870891/14309257/e962e660-fbe3-11e5-8ef1-6158342cdac9.png)  
Fill in the card:  
![image](https://cloud.githubusercontent.com/assets/14870891/14309488/6f80241e-fbe5-11e5-82c2-2c4fdf18eae1.png)  
Upload this icon for the bot, or choose another:  
![z_logo](https://cloud.githubusercontent.com/assets/14870891/14309527/bbcf9c00-fbe5-11e5-9849-d7bc1aae374f.png)  

Once your bot is ready, invite it to the channel, where you want it to post.
to do this in Slack channel type:  
```
/invite @zabbix_bot
```


## Test with Slack 
Once you have done , go back to console and test the script by running it under user Zabbix:  
```
root#:su - zabbix
cd /usr/local/share/zabbix/alertscripts
```

 
To ADD ALARM
```
./zbx-notify @your_name_in_slack_here 'PROBLEM:myHOSTNAME Temperature Failure on DAE5S Bus 1 Enclosure 1' 'Host: myHOSTNAME \
Trigger: PROBLEM: myHOSTNAME Temperature Failure on DAE5S Bus 1 Enclosure 1: High \
Timestamp: 2016.03.14 11:57:10 YEKT eventid: 100502' --api_token=your_token_here --slack
```
To CLEAR ALARM RUN
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
Fill **Script paramters** in the following order  
1: `{ALERT.SENDTO}`  
2: `{ALERT.SUBJECT}`  
3: `{ALERT.MESSAGE}`  
4: `--api_token=you_token_here`  
5: `--slack`  
Note that there should be no ticks or quotes after `--api-token=` only the key itself.  
You may provide additional params as well, by pressing **Add** and filling them in the form:  
`--param=value`  

Here is what you can setup for Slack:  

| Parameter        | Description                      | Default value  | Example value                           | JSON mode(see below)  |  
| ---------------- |:---------------------:|:--------------:|-----------------------------------------|----|  
| api_token        |  you bot api token(Mandatory)    | none           |--api_token=xoxb-30461853043-mQE7IGah4bGeC15T5gua4IzK|  Yes |  
| slack_mode        |  operation mode(event or alarm)   | event           |--slack_mode=event|    Yes |
| debug        |  For providing debug output, useful when running from command line   |   none         |--debug|    Yes |
| nofork        |  To prevent script from forking on posting to Slack    |   none         |--nofork|    Yes |
| no-ssl_verify_hostname        |  To ignore SSL certificate validation failures.   |   none         |--no-ssl_verify_hostname|    Yes |

Press *Add* to finish media type creation.  

### User creation
As you finish with defining new Media Type for Slack proceed to next step and create impersonal user:  
Go to **Administration->Users**  press **Create user**:  

**In User tab:**  
**Alias**: Notification Agent  
**Groups**: Make sure you add him proper Group Membership so this user has the rights to see new Events (and so notify on them).  
**Password**: anything complex you like, you will never use it  
![image](https://cloud.githubusercontent.com/assets/14870891/14313150/9eacdc1a-fbf8-11e5-9bbd-6ed239d0c599.png)  
 
**In Media tab:**  
Create New media:  
**Type:** Slack  
**Send to:** Place your Slack #channel name here for example #zabbix.  
![image](https://cloud.githubusercontent.com/assets/14870891/14527650/145abfac-0254-11e6-8875-ec42aff616b4.png)  



Note You can also define new media for real Zabbix users: use their Slack name in 'Send to'  preceded by @ (for example @bob). In that case this users can be notified by Direct Message as well.  

 

 
### Action creation:
Create new action (go to **Configuration -> Action** ,choose  **Event source: Triggers** press **Create action**) that is to be send to Slack.  
Here is the example:  
In **Action** tab:  
Default/recovery subject: anything you like, but I recommend  
```
{TRIGGER.STATUS}:{HOSTNAME}:{TRIGGER.NAME}. 
```
Default message:  
anything you like, for example:  
```
Host: {HOSTNAME}
Trigger: {STATUS}: {TRIGGER.NAME}: {TRIGGER.SEVERITY}
Timestamp: {EVENT.DATE} {EVENT.TIME}
{TRIGGER.COMMENT}
{TRIGGER.URL}
http://zabbix.local
Eventid: {EVENT.ID}
```
Recovery message:  
```
Host: {HOSTNAME}
Trigger: {STATUS}: {TRIGGER.NAME}: {TRIGGER.SEVERITY}
Timestamp: {EVENT.RECOVERY.DATE} {EVENT.RECOVERY.TIME}
{TRIGGER.COMMENT}
{TRIGGER.URL}
http://zabbix.local
Eventid: {EVENT.ID}
```
Note:  if you place Macros **{TRIGGER.SEVERITY}** and **{STATUS}** then your messages in Slack will be color coded.  
Note:  place line `Eventid: {EVENT.ID}` if you want to use Alarm mode    
![image](https://cloud.githubusercontent.com/assets/14870891/14313896/f3edc7e4-fbfc-11e5-842a-2e7410c8d755.png)  

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
            "title_link": "http://zabbux/tr_events.php?triggerid={TRIGGER.ID}&eventid={EVENT.RECOVERY.ID}",
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

 
 
In **Condition** tab do not forget to include **Trigger value = Problem condition**. The rest depends on your needs.  
![image](https://cloud.githubusercontent.com/assets/14870891/14313939/2ae4e980-fbfd-11e5-96db-81325b6d40b0.png)
 
In **Operations** tab select Notification Agent as recipient of the message sent via Slack.  
![image](https://cloud.githubusercontent.com/assets/14870891/14314053/d123e30a-fbfd-11e5-8717-74113151b4da.png)  

More on Action configuration in Zabbix can be found  [here:](https://www.zabbix.com/documentation/3.0/manual/config/notifications/action)    

That it is it  

# HipChat Setup  
Now HipChat. Again if you don't have account there you can create it [here](https://www.hipchat.com/sign_up):  

First choose a HipChat **room** where you want your events from Zabbix to land. 
Then you will need to create new Notification **token** inside this **room**:  
![image](https://cloud.githubusercontent.com/assets/14870891/14525508/78c1ab26-0246-11e6-9e9e-48f3e9fd0ef1.png)
once finished copy token, you will need in Zabbix.  

## Test with HipChat 
Once you have done , go back to console and test the script by running it under user Zabbix:  
```
root#:su - zabbix
cd /usr/local/share/zabbix/alertscripts
```

To ADD ALARM
```
./zbx-notify 'roomname' 'PROBLEM:myHOSTNAME Temperature Failure on DAE5S Bus 1 Enclosure 1' \
'Host: myHOSTNAME \
Trigger: PROBLEM: myHOSTNAME Температуа Failure on DAE5S Bus 1 Enclosure 1: High \
Timestamp: 2016.03.14 11:57:10 eventid: 100502' \
--api_token=5y9zBYM4Htgg4SNrYovMGE1uGvyrUtFOQGHXdK3J \
--hipchat
```


## Zabbix Configuration (HipChat)
Now all is left is to setup new Action and Media Type.  
### Media type  
First go to **Administration -> Media Types**, press **Create media type**  
![image](https://cloud.githubusercontent.com/assets/14870891/14527483/08648d8c-0253-11e6-810b-94e1e9a5a179.png)  
Choose Type: *Script*  
Name: *HipChat*  
Script name: *zbx-notify*  
Fill **Script parameters** in the following order  
1: `{ALERT.SENDTO}`  
2: `{ALERT.SUBJECT}`  
3: `{ALERT.MESSAGE}`  
4: `--api_token=you_token_here`  
5: `--hipchat`  
Note that there should be no ticks or quotes after `--api-token=` only the key itself.  
You may provide additional params as well, by pressing **Add** and filling them in the form:  
`--param=value`  

Here is what you can setup for HipChat:  

| Parameter        | Description                      | Default value  | Example value                           |  JSON mode (see below)  |
| ---------------- |:---------------------:|:--------------:|-----------------------------------------|---|  
| api_token        |  you bot api token(Mandatory)    | none           |--api_token=5y9zBYM4Htgg4SNrYovMGE1uGvyrUtFOQGHXdK3J| Yes |  
| hipchat_api_url        |  HipChat api url endpoint   | https://api.hipchat.com          |--hipchat_api_url=https://192.168.10.0/hipchat | Yes |
| hipchat_message_format        |  text or html(see API documentation)   | text           |--hipchat_message_format=html|  Ignored  |
| hipchat_notify        |  whether to notify HipChat users on new message arrival   | true           |--hipchat_notify=false|  Ignored  |
| hipchat_from        |  Additional user name in HipChat   | none           |--hipchat_from='Zabbix NW Instance'|  Ignored  |
| debug        |  For providing debug output, useful when running from command line   |   none         |--debug|  Yes |
| nofork        |  To prevent script from forking on posting to Slack    |   none         |--nofork|  Yes |
| no-ssl_verify_hostname        |  To ignore SSL certificate validation failures.   |   none         |--no-ssl_verify_hostname|    Yes |

Press *Add* to finish media type creation.  

### User creation
As you finish with defining new Media Type for HipChat proceed to next step and create impersonal user:  
Go to **Administration->Users**  press **Create user**:  

**In User tab:**  
**Alias**: Notification Agent  
**Groups**: Make sure you add him proper Group Membership so this user has the rights to see new Events (and so notify on them).  
**Password**: anything complex you like, you will never use it  
![image](https://cloud.githubusercontent.com/assets/14870891/14313150/9eacdc1a-fbf8-11e5-9bbd-6ed239d0c599.png)  

**In Media tab:**  
Create New media:  
**Type:** HipChat  
**Send to:** Place your HipChat room name here for example **Zbx-test**.  
![image](https://cloud.githubusercontent.com/assets/14870891/14527732/a214b26c-0254-11e6-9feb-ffcbfca3d402.png)  

 
### Action creation:
Create new action (go to **Configuration -> Action** ,choose  **Event source: Triggers** press **Create action**) that is to be send to HipChat.  
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

Note:  if you place Macros **{TRIGGER.SEVERITY}** and **{STATUS}** then your messages in HipChat will be color coded.  

As an alternative you can place JSON object here that would represent HipChat  
See send_room_notification [API](https://www.hipchat.com/docs/apiv2/method/send_room_notification).  
Note though, that it is required to place all Zabbix MACROS in double brackets [[ ]], so they are properly transformed into JSON String.  

 
 
In **Condition** tab do not forget to include **Trigger value = Problem condition**. The rest depends on your needs.  
![image](https://cloud.githubusercontent.com/assets/14870891/14313939/2ae4e980-fbfd-11e5-96db-81325b6d40b0.png)
 
In **Operations** tab select Notification Agent as recipient of the message sent via HipChat.  
![image](https://cloud.githubusercontent.com/assets/14870891/14532200/e5b21abe-0268-11e6-9ee8-b1b0244a58d6.png)  


More on Action configuration in Zabbix can be found  [here:](https://www.zabbix.com/documentation/3.0/manual/config/notifications/action)    

That it is it again.  


# PagerDuty Setup  
And *finally* PagerDuty. If your team doesn't have the account you can get it [here](https://signup.pagerduty.com/accounts/new)  

Once inside PagerDuty you will need to setup **Services** that will provide you with data. To do this go to **Configuration->Services**:  
![image](https://cloud.githubusercontent.com/assets/14870891/14526382/88ead7fc-024b-11e6-9025-999f6a477e00.png)
On the next page choose Zabbix from the list of services and choose a name for your Zabbix installation:
![image](https://cloud.githubusercontent.com/assets/14870891/14526388/954236a8-024b-11e6-84a6-189e527e01b5.png)
You will see Service key on the next page: save it somewhere as you will need this in Zabbix.

## Test with PagerDuty 
Once you have done the previous setp , go back to console and test the script by running it under user Zabbix:  
```
root#:su - zabbix
cd /usr/local/share/zabbix/alertscripts
```

To ADD ALARM  
```
./zbx-notify pagerduty 'PROBLEM:myHOSTNAME Temperature Failure on DAE5S Bus 1 Enclosure 1' \
'Host: myHOSTNAME \
Trigger: PROBLEM: myHOSTNAME Температуа Failure on DAE5S Bus 1 Enclosure 1: High \
Timestamp: 2016.03.14 11:57:10 eventid: 100502' \
--api_token=1baff6f955c040d795387e7ab9d62090 \
--pagerduty --nofork
```
To RESOLVE IT  
```
./zbx-notify pagerduty 'OK:myHOSTNAME Temperature Failure on DAE5S Bus 1 Enclosure 1' \
'Host: myHOSTNAME \
Trigger: OK: myHOSTNAME Температуа Failure on DAE5S Bus 1 Enclosure 1: High \
Timestamp: 2016.03.14 11:57:10 eventid: 100502' \
--api_token=1baff6f955c040d795387e7ab9d62090 \
--pagerduty --nofork
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
| nofork       |  To prevent script from forking on posting to Slack    |   none         |--nofork|  Yes |
| no-ssl_verify_hostname        |  To ignore SSL certificate validation failures.   |   none         |--no-ssl_verify_hostname|    Yes |

Press *Add* to finish media type creation.  

### User creation
As you finish with defining new Media Type for PagerDuty proceed to next step and create impersonal user:  
Go to **Administration->Users**  press **Create user**:  

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
Create new action (go to **Configuration -> Action** ,choose  **Event source: Triggers** press **Create action**) that is to be send to PagerDuty.  
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
Note though, that it is required to place all Zabbix MACROS in double brackets [[ ]], so they are properly transformed into JSON String.  
For TRIGGER transitioning to PROBLEM you might use(Default Message):  
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
 
 
In **Condition** tab do not forget to include **Trigger value = Problem condition**. The rest depends on your needs.  
![image](https://cloud.githubusercontent.com/assets/14870891/14313939/2ae4e980-fbfd-11e5-96db-81325b6d40b0.png)
 
In **Operations** tab select Notification Agent as recipient of the message sent via PagerDuty.  
![image](https://cloud.githubusercontent.com/assets/14870891/14532236/0ef4ea8c-0269-11e6-8315-a711dda53506.png)  

More on Action configuration in Zabbix can be found  [here:](https://www.zabbix.com/documentation/3.0/manual/config/notifications/action)    




# Troubleshooting
In order to troubleshoot problems, try to send test message from the command line under user `zabbix`.  
Try using `--nofork` and `--debug` command line switches  

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
