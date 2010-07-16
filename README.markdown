
# Koala Video Server #

* What is it?
  * Koala is an open-source solution for encoding videos.
  * Designed to work with Amazon's EC2 computing and S3 storage platforms.
  * Focused on being fast and scalable    
* What technologies does it use?
  * Koala is built using [Sinatra](http://www.sinatrarb.com/) and [Redis](http://code.google.com/p/redis/)
  * Computationally intensive tasks are queued in the background and processed using [Resque](http://github.com/defunkt/resque).
  * `ffmpeg` is used to encode the videos
* What features does it currently support?
  * Multiple web-apps(clients)
  * Encoding of videos stored on S3
  * Running multiple encoding workers

## Requirements ##

To start using and/or contributing to Koala, you will need to install and setup the following:

* Ruby 1.8.7 (as of this writing the [rVideo](http://github.com/zencoder/rvideo) gem and its dependencies don't work with Ruby 1.9)
* [Redis](http://code.google.com/p/redis/)
* [Resque](http://github.com/defunkt/resque)
* [ffmpeg](http://www.ffmpeg.org/)
* [rVideo](http://github.com/zencoder/rvideo)
* [aws-s3](http://rubygems.org/gems/aws-s3)
* [Nginx](http://nginx.org/) - _optional - see Note 1_
* [Nginx Upload Module](http://github.com/vkholodkov/nginx-upload-module) - _optional - see Note 1_
* [Phusion Passenger for Nginx](http://www.modrails.com/) - _optional - see Note 1_

**Note 1:**
There are two ways to encode videos with Koala. The recommended way is to utilize Koala's cloud-centric design and provide its API with a URI to a video stored on S3. The second way is to upload a video to Koala through its API. Since one of the goals of Koala is to be fast and scalable, multipart file uploading has been outsourced to Nginx and the excellent Nginx Upload module. Thus if you don't require the upload feature, Nginx and the Nginx upload module are not required. A sample nginx.conf has been provided for those that do require this feature.

## Installation and Setup

The following describes the steps required to setup Koala on a machine running Ubuntu (tested with 9.04, 9.10, 10.04). The procedure for other distros should be similar.

### Install Ruby 

As always, begin with an up-to-date system

    sudo apt-get update
    sudo apt-get dist-upgrade

Next, install Ruby 1.8.7 from the repos

    sudo apt-get install ruby ruby-dev libopenssl-ruby1.8 irb ri rdoc rake

We'll need latest the latest RubyGems

    wget http://production.cf.rubygems.org/rubygems/rubygems-1.3.7.tgz
    tar xvfz rubygems-1.3.7
    ruby setup.rb

### Install Redis and Resque
 
Once we have Ruby and friends installed, we need a database for Koala to connect to. Koala relies on Redis to be blazing fast

    wget http://redis.googlecode.com/files/redis-1.2.6.tar.gz
    tar xvfz redis-1.2.6.tar.gz
    cd redis-1.2.6
    make

Note: the above will need to be done in a folder accessible in your `$PATH`. I usually place it in `/usr/local/bin`

To test Redis, type the following in your terminal

    redis-server

The above should start the redis-server without any configuration. If you don't see anything displayed or if the system can't find the command, ensure that you installed Redis in a directory listed in your `$PATH`.

Once you've installed Redis, install supporting gems

    sudo gem install redis redis-namespace json

Koala uses Resque to queue and process the encoding of videos as well as other computationally intensive tasks, we can install it with

    sudo gem install resque

### Install ffmpeg and rVideo

This is probably the most involved and complicated task during the setup - especially if something goes wrong. If you're installing this on Ubuntu then the following should make the process fairly painless.

Begin by installing `ffmpeg` according to [this guide](http://ubuntuforums.org/showthread.php?t=786095) (specific to Ubuntu)

Once installation completes, install the rVideo gem

    sudo gem install rvideo

There is a small error in this version of the gem. To fix, find the path to where the rvideo gem is installed and change the following (found under `rvideo-0.9.3/lib/rvideo/inspector.rb`)

    metadata = /(Input \#.*)\nMust/m.match(@raw_response)

change to

    metadata = /(Input \#.*)\n.+\n\Z/m.match(@raw_response) 

### Install miscellaneous dependencies

    sudo gem install aws-s3

### Install and setup Nginx with Passenger (optional)

If you're planning on just evaluating Koala or contributing to the project this part is optional. If you want to deploy Koala as a service then I strongly recommend going through these steps to setup Nginx with Passenger.

My preferred way of setting up Nginx is through the Passenger gem as they include an amazing interactive installer that greatly simplifies the installation; however, since we'll also be adding the [Nginx Upload Module](http://github.com/vkholodkov/nginx-upload-module) we'll need the source code for both Nginx and the module.

Get the Nginx Upload Module source

    wget http://www.grid.net.ru/nginx/download/nginx_upload_module-2.0.11.tar.gz
    tar xvfz nginx_upload_module-2.0.11.tar.gz

Get the Nginx source

    wget http://nginx.org/download/nginx-0.7.65.tar.gz
    tar xvfz nginx-0.7.65.tar.gz

Take note of the path to where you extracted the above as you'll need them when installing Passenger. Next, install the Phusion Passenger gem

    sudo gem install passenger

Now we're ready to let Passenger install Nginx for us

    passenger-install-nginx-module

Read the instructions in the installer carefully, when presented with the install option, choose 2 (Advanced Install). Next, the installer will ask you for the path to the Nginx source, enter the full path and continue.

When it asks you for any additional parameters, enter the following line

    --add-module='/path/to/extracted/nginx_upload_module_source'

Once the installation completes, doing a `sudo nginx` should start the server (test by visiting the url of the server through a browser).

Koala includes a sample `nginx.conf` you can copy and use, it has the configuration options for the upload module already baked in.

## Running Koala ##

Once you have met the installation requirements, follow these steps to get Koala up and running

1. Edit the `config/settings.yml` file to include your S3 credentials and other settings pertaining to your environment
2. Koala comes with two Redis configuration files (one for development, the other for testing). You can start the redis server with the following
            
        redis-server config/redis/development.config

3a. If not using the upload module, you can use rackup to serve the app:

        rackup -p 3000 -s webrick

4b. Otherwise start Nginx and the Upload module with:

        sudo nginx

5. Koala uses Resque to queue and process background tasks that are computationally intensive. To start processing queued tasks, you can use the following:

        QUEUES=videos,encodings,notifications rake resque:work

## Running Test Suite ##

Koala's Test Suite is written using Test::Unit. Follow these steps to run Koala's Test Suite.

1. Start the redis server for the test environment:

        redis-server config/redis/test.config

2. Run the test suite:

        thor monk:test

# Koala Detailed Operation #

Koala allows multiple clients (multiple web-apps or a single web-app across multiple hosts) to send videos in different formats and have those videos encoded based on defined encoding profiles. Once a video is done encoding, a notification is sent to the client/host which made the initial request.

## How does it do this? ##

### Clients 
The first thing Koala needs in order to encode videos is a client. A client is essentially a web-application that communicates with Koala's API and which Koala can notify once an a video has finished encoding. Koala supports multiple clients, these can be separate web-applications or a single web-application running on multiple hosts. When creating a client, there are several pieces of information you will need to provide.

1. `Name` - each client requires a unique name
2. `S3 Bucket` - each client requires a unique S3 Bucket where it will store its encoded videos and associated files
3. `Notification URL` _(optional)_ - you can specify a notification url for each client. Koala will attempt to send a notification to this URL once a video has finished encoding. If no notification url is provided, Koala will not send any notifications to this client.

Once a client is created, there are several things that Koala does in the background. It first associates encoding profiles with the client. Encoding profiles are detailed below but essentially each client can have one or more encoding profiles that will be used to encode any video for this client. Secondly, Koala generates a unique API key (called an access key) for the client. This API key is used to authenticate the client when making calls to Koala's API.

###Profiles 
Profiles are what determines how a video will encode. They support most of the settings that `ffmpeg` does. Koala comes with two default profiles - they are defined in `config/profiles.yml`. To disable an encoding profile, simply comment out its definition in the YML file. Feel free to also add your own.

###Encodings
Encodings are the output of the encoding process. When a video is sent to Koala for encoding, either through uploading or sending its S3 key via the API, Koala will create an encoding for each encoding profile associated with the client. Once an encoding is complete, it is stored on S3 and ready to be accessed by the calling application.

###Notifications
Koala can be configured to notify the client making the encoding request once all encodings for a video are complete. By setting a clients Notification URL, you tell Koala that this client should be notified. Once all encodings for a video are complete, Koala will send a notification to a URL configured for the client. The notification is a JSON object in the following format:

    {\"video_thumbnail\":\"https://s3.amazonaws.com/bucket_name/koala_videos/34/Movie_1_original_thumb.jpg\",
    \"video_id\":\"34\",\"encodings\":[{\"state\":\"completed\",\"id\":34,\"filename\":\"Movie_1_original_HD.flv\"}],\"video_state\":\"completed\"}

# API Documentation #

Koala provides a RESTful API for communicating with its clients. The following describes the API.

## Videos ##

###Getting information about all videos###

    http://your-koala-server.com/api/clients/:id/videos

**Arguments**

* `access_key` - the clients given access_key, required for authentication

**Example Response**

If authentication is successful, the following JSON is returned:

    {"videos":["{\"filepath\":\"https://s3.amazonaws.com/bucket_name/koala_videos/10/Movie_1_original.mov\",
    \"audio_codec\":\"aac\",\"video_bitrate\":\"1736\",\"thumbnail_filename\":\"Movie_1_original_thumb.jpg\",\"audio_sample_rate\":\"44100\",\"client_id\":\"1\",
    \"thumbnail_filepath\":\"https://s3.amazonaws.com/bucket_name/koala_videos/10/Movie_1_original_thumb.jpg\",\"error_msg\":null,
    \"container\":\"mov,mp4,m4a,3gp,3g2,mj2\",\"video_codec\":\"mpeg4\",\"width\":\"640\",\"fps\":\"59.75\",\"id\":\"10\",\"state\":\"completed\",
    \"height\":\"480\",\"duration\":\"15580\",\"filename\":\"/medias/4/Movie_1_original.mov\"}"]}

###Getting information about a particular video###

    http://your-koala-server.com/api/clients/:id/videos/:video_id

**Arguments**

* `access_key` - the clients given access_key, required for authentication

**Example Response**

If authentication is successful, the following JSON is returned:

    {"video":"{\"filepath\":\"https://s3.amazonaws.com/bucket_name/koala_videos/10/Movie_1_original.mov\",\"audio_codec\":\"aac\",
    \"video_bitrate\":\"1736\",\"audio_sample_rate\":\"44100\",\"thumbnail_filename\":\"Movie_1_original_thumb.jpg\",
    \"thumbnail_filepath\":\"https://s3.amazonaws.com/bucket_name/koala_videos/10/Movie_1_original_thumb.jpg\",\"client_id\":\"1\",
    \"container\":\"mov,mp4,m4a,3gp,3g2,mj2\",\"error_msg\":null,
    \"encodings\":[{\"filepath\":\"https://s3.amazonaws.com/bucket_name/koala_videos/10/Movie_1_original_HD.flv\",
    \"started_encoding_at\":\"Mon Mar 01 21:56:07 -0500 2010\",\"video_id\":\"10\",\"finished_encoding_at\":\"Mon Mar 01 21:56:09 -0500 2010\",
    \"client_id\":\"1\",\"profile_id\":\"1\",\"id\":\"10\",\"state\":\"completed\",\"filename\":\"Movie_1_original_HD.flv\"}],\"video_codec\":\"mpeg4\",
    \"width\":\"640\",\"fps\":\"59.75\",\"id\":\"10\",\"filename\":\"/medias/4/Movie_1_original.mov\",\"duration\":\"15580\",\"height\":\"480\",
    \"state\":\"completed\"}"}

###Uploading a video###

POST to:

    http://your-koala-server.com/api/clients/:id/videos/upload

**Arguments**

* `access_key` - the clients given access_key, required for authentication

**Note:** You will need Nginx setup with the upload module. A sample nginx.conf is included with this app.

**Example Response**

If authentication is successful, the following JSON is returned:

    {"video":"{\"filepath\":\"/Users/bart/Development/koala_cleanup/public/data/tmp_uploads/0000000001_Movie1.mov\",
    \"audio_codec\":null,\"video_bitrate\":null,\"thumbnail_filename\":null,\"audio_sample_rate\":null,\"client_id\":\"1\",\"thumbnail_filepath\":null,
    \"error_msg\":null,\"container\":null,\"video_codec\":null,\"width\":null,\"fps\":null,\"id\":\"31\",\"state\":\"queued\",\"height\":null,\"duration\":null,
    \"filename\":\"Movie1.mov\"}"}

###Encoding a video###

POST to:

    http://your-koala-server.com/api/clients/:id/videos/encode

**Arguments**

* `access_key` - the clients given access_key, required for authentication
* `video[filename]` - the name of the video on s3, this can either be the key to the file or the full S3 URI to the file.

**Example Response**

If authentication is successful and the video is found to exist on S3, the following JSON is returned:

    {"video":"{\"filepath\":null,\"audio_codec\":null,\"video_bitrate\":null,\"thumbnail_filename\":null,\"audio_sample_rate\":null,\"client_id\":\"1\",
    \"thumbnail_filepath\":null,\"error_msg\":null,\"container\":null,\"video_codec\":null,\"width\":null,\"fps\":null,\"id\":\"32\",\"state\":\"created\",
    \"height\":null,\"duration\":null,\"filename\":\"/medias/4/Movie_1_original.mov\"}"}

##Encodings##

###Getting information about a particular encoding###

    http://your-koala-server.com/api/clients/:id/encodings/:encoding_id

**Arguments**

* `access_key` - the clients given access_key, required for authentication

**Example Response**

If authentication is successful and the video is found to exist on S3, the following JSON is returned:

    {"encoding":"{\"filepath\":\"https://s3.amazonaws.com/bucket_name/koala_videos/10/Movie_1_original_HD.flv\",
    \"started_encoding_at\":\"Mon Mar 01 21:56:07 -0500 2010\",\"video_id\":\"10\",\"finished_encoding_at\":\"Mon Mar 01 21:56:09 -0500 2010\",
    \"client_id\":\"1\",\"profile_id\":\"1\",\"id\":\"10\",\"state\":\"completed\",\"filename\":\"Movie_1_original_HD.flv\"}"}

# Contribute #

If you would like to contribute to Koala, there are several things that still need work.

* Bugs/Patches - submit them through github
* Authentication - at the moment, the front-end does not have any authentication
* Ruby 1.9.1 Support

# License #

Released under the MIT license.