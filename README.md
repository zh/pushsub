# PuSHSub

PuSH (PubSubHubbub) subscriber with Websockets notifications ( provided by [Pusher](http://pusherapp.com/) )

## Needed gems (.gems)

    sinatra
    sequel
    simple-rss
    json
    pusher

## Heroku config (environment variables)

    heroku config:add PUSH_ID=1234
    heroku config:add PUSH_KEY=xxxxxxxxxxxxxxxxxxxx
    heroku config:add PUSH_SECRET=yyyyyyyyyyyyyyyyyyyy
    heroku config:add AUSER=admin
    heroku config:add APASS=secret

## Usage

### Using preinstalled application on [http://pushsub.heroku.com/](http://pushsub.heroku.com/)

 * Click the **"Create"** button. This will create a new subscription page. 
 * In the PuSH hub ( I prefer [Superfeedr](http://superfeedr.com/) ) subscription form enter:

   * Action: subscribe
   * Topic: {some feed url}
   * Callback: http://pushsub.heroku.com/sub/XXXXX  - the Callback URL, displayed on the top of the page, you just created.
 * When there are changes in your feed, the new items will be displayed in near real time on your subscription page.

### Your own install

PuSHSub application is using [Pusher](http://pusherapp.com/) channels for Websockets notifications. If you do not need these notifications, do not define *PUSH_ID* environment variable.

If you decided to use Websockets notifications:
 
 * In your [Pusher](http://pusherapp.com/) account - *"Add new app"*
 * From the *"Api access"* page use the *API Credentials* to configure your *PUSH_ID*, *PUSH_KEY* and *PUSH_SECRET* environment variables
 * In the PuSH hub subscription form use *http://{you_installation_url}/sub/XXXXX* for Callback URL
