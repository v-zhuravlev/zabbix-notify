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
**Slack:**  
-	Color coding events depending on Trigger Status and Severity  
-	Recovery message from Zabbix will update and then delete already posted message in Slack (--mode=alarm)  
-	Recovery message from Zabbix will be posted as new message (--mode=event)  
-	JSON can be used to compose Slack messages. See Slack [message attachments](https://api.slack.com/docs/attachments)  

**HipChat:**  
-	Color coding events depending on Trigger Status and Severity
-	HTML or plain text can be used to format HipChat messages.

**PagerDuty:**  
-	Recovery message from Zabbix will resolve already created incident in PagerDuty


There are limitations to note as well:  
-	Slack and HipChat can reject you messages if you are sending them too often (more then 1 per second). It can accept short bursts but If you continue to spam - you will be blocked for one minute or so. So use Acton Conditions wisely to avoid event storms.


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

## Zabbix Server preparations  
Now switch back to Zabbix Server.  
The script is written in Perl and you will also need those common modules in order to run it:  
```
LWP
JSON::XS
Class:Tiny
```
In Debian you can install them by typing:
```
apt-get install libwww-perl libjson-xs-perl  
```
In Centos  you can do it like so:  
```
yum install perl-JSON-XS perl-libwww-perl
```
Install Class::Tiny(and others if you want) from CPAN:  
```
PERL_MM_USE_DEFAULT=1 perl -MCPAN -e 'install Bundle::LWP'
PERL_MM_USE_DEFAULT=1 perl -MCPAN -e 'install JSON::XS
PERL_MM_USE_DEFAULT=1 perl -MCPAN -e 'install Class::Tiny'
```
or cpanminus (faster):  
```
apt-get install cpanminus
```
and then  
```
cpanm install LWP
cpanm install JSON::XS
cpanm install Class::Tiny
```
Once this is done, download tar and install it into the system:  
```
perl Makefile.PL INSTALLSITESCRIPT=/usr/local/share/zabbix/alertscripts
make test
make install
```
where INSTALLSITESCRIPT is your Zabbix's  alert script folder as defined in zabbix_server.conf.  

Please note that currently `make test` requires Internet connection to test with mocks :) So skip if you don't have one.  

Once installed, test the script by running it under user Zabbix:  
```
root#:su - zabbix
cd /usr/local/share/zabbix/alertscripts
```
To ADD ALARM
```
zbx-slack @your_name_in_slack_here 'PROBLEM:myHOSTNAME Temperature Failure on DAE5S Bus 1 Enclosure 1' 'Host: myHOSTNAME
Trigger: PROBLEM: myHOSTNAME Temperature Failure on DAE5S Bus 1 Enclosure 1: High
Timestamp: 2016.03.14 11:57:10 YEKT eventid: 100502' --api_token=you token here
```
To CLEAR ALARM RUN
```
zbx-slack @your_name_in_slack_here 'OK:myHOSTNAME Temperature Failure on DAE5S Bus 1 Enclosure 1' 'Host: myHOSTNAME
Trigger: OK: myHOSTNAME Temperature Failure on DAE5S Bus 1 Enclosure 1: High
Timestamp: 2016.03.14 11:57:10 YEKT eventid: 100502' --api_token=you token here
```

## Zabbix Configuration (Slack)
Now all is left is to setup new Action and Media Type.  
### Media type  
First go to **Administration -> Media Types**, press **Create media type**  
![image](https://cloud.githubusercontent.com/assets/14870891/14310249/9eb38baa-fbe9-11e5-8f1c-f0d83125555a.png)
Choose Type: *Script*  
Name: *Slack*  
Script name: *zbx-slack*  
Fill **Script paramters** in the following order  
1: `{ALERT.SENDTO}`  
2: `{ALERT.SUBJECT}`  
3: `{ALERT.MESSAGE}`  
4: `--api_token=you_token_here`  
Note that there should be no ticks or quotes after `--api-token=` only the key itself.  
You may provide additional params as well, by pressing **Add** and filling them in the form:  
`--param=value`  

Here is what you can setup for Slack:  

| Parameter        | Description                      | Default value  | Example value                           |  
| ---------------- |:---------------------:|:--------------:|-----------------------------------------|  
| api_token        |  you bot api token(Mandatory)    | none           |--api_token=xoxb-30461853043-mQE7IGah4bGeC15T5gua4IzK|  
| mode        |  operation mode(alarm or event)   | alarm           |--mode=event|  
| debug        |  For providing debug output, useful when running from command line   |   none         |--debug|  

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
![image](https://cloud.githubusercontent.com/assets/14870891/14313361/e3a86ed2-fbf9-11e5-87e9-515212f4ded8.png)


Note You can also define new media for real Zabbix users: use their Slack name in 'Send to'  preceded by @ (for example @bob). In that case this users can be notified by Direct Message as well.  

 

 
### Action creation:
Create new action (go to **Configuration -> Action** ,choose  **Event source: Triggers** press **Create action**) that is to be send to Slack.  
Here is the example:  
In **Action** tab:  
Default/recovery subject: anything you like, but I recommend  
```
{TRIGGER.STATUS}:{HOSTNAME}:{TRIGGER.NAME}. 
```
Default/recovery message:  
anything you like, but I recommend:  
```
Host: {HOSTNAME}
Trigger: {STATUS}: {TRIGGER.NAME}: {TRIGGER.SEVERITY}
Timestamp: {DATE} {EVENT.TIME}
{TRIGGER.COMMENT}
{TRIGGER.URL}
{INVENTORY.LOCATION}
eventid: {EVENT.ID}
```
Note:  if you place Macros **{TRIGGER.SEVERITY}** and **{STATUS}** then your messages in Slack will be color coded.  
Note:  place line `eventid: {EVENT.ID}` if you want to use Alarm mode (which is default)  
![image](https://cloud.githubusercontent.com/assets/14870891/14313896/f3edc7e4-fbfc-11e5-842a-2e7410c8d755.png)  
As an alternative you can place JSON object here that would represent Slack [attachment:](https://api.slack.com/docs/attachments)  
```
{
            "fallback": "{STATUS} : {HOSTNAME} : {TRIGGER.NAME} fallback",
            "pretext": "{STATUS} : {HOSTNAME} : {TRIGGER.NAME} appears above the attachment block",

            "title": "{STATUS} : {HOSTNAME} : {TRIGGER.NAME}",
            "title_link": "URL TO ",

            "text": "{STATUS} eventid: {EVENT.ID} that appears within the attachment",

            "fields": [
                {
                    "title": "Priority",
                    "value": "{TRIGGER.SEVERITY}",
                    "short": false
                }
            ],

            "image_url": "http://my-website.com/path/to/image.jpg",
            "thumb_url": "http://example.com/path/to/thumb.png"
}
```

 
In **Condition** tab do not forget to include **Trigger value = Problem condition**. The rest depends on your needs.  
![image](https://cloud.githubusercontent.com/assets/14870891/14313939/2ae4e980-fbfd-11e5-96db-81325b6d40b0.png)
 
In **Operations** tab select Notification Agent as recipient of the message sent via Slack.  
![image](https://cloud.githubusercontent.com/assets/14870891/14314053/d123e30a-fbfd-11e5-8717-74113151b4da.png)  

More on Action configuration in Zabbix can be found  [here:](https://www.zabbix.com/documentation/3.0/manual/config/notifications/action)    

That it is it  

# Troubleshooting
In order to troubleshoot problems, try to send test message from the command line under user `zabbix`.  

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
