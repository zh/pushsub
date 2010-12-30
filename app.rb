#!/usr/bin/env ruby

$KCODE = 'u'
%w{jcode cgi open-uri logger rubygems sinatra sequel json pusher global}.each {|lib| require lib}
require 'simple-rss'

configure do
  enable :logging
  disable :sessions
  set :environment, ENV['RACK_ENV']

  DB = Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://items.db')
  
  unless DB.table_exists? "items"
    DB.create_table :items do
      primary_key :id
      foreign_key :topic_id
      String :title, :null=>false 
      String :content
      String :link, :null=>false, :unique => true
      DateTime :created
      index :created
      index :link
    end
  end

  unless DB.table_exists? "topics"
    DB.create_table :topics do
      primary_key :id
      String :name, :null=>false, :unique => true
      DateTime :created
      index :name
      index :created
    end
  end

  AUSER = ENV['AUSER'] || 'admin'
  APASS = ENV['APASS'] || 'secret'
  USE_PUSHER = false
  if ENV['PUSH_ID']
    Pusher.app_id = ENV['PUSH_ID']
    Pusher.key = ENV['PUSH_KEY']
    Pusher.secret = ENV['PUSH_SECRET']
    USE_PUSHER = true
  end  
end

helpers do
  def protected!
    response['WWW-Authenticate'] = %(Basic realm="Protected Area") and \
    throw(:halt, [401, "Not authorized\n"]) and \
    return unless authorized?
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [AUSER, APASS]
  end
end

get '/' do
  erb :index
end

post '/' do
  @key = gen_id
  @key = gen_id until DB[:topics].filter(:name => @key).empty?
  DB[:topics].insert(:name => @key, :created => Time.now)
  redirect("/t/#{@key}")
end

get '/t/:topic/?' do |topic|
  @topic = DB[:topics].filter(:name => topic).first
  throw :halt, [404, "Invalid data"] unless @topic
  if params['clear'] && params['clear'] == APASS
    DB[:items].filter(:topic_id=>@topic[:id]).delete
    @items = []
    redirect('/admin') if params['admin']
  else
    @items = DB[:items].filter(:topic_id=>@topic[:id]).order(:created.desc).limit(20)
  end  
  erb :topic
end 

get '/admin/?' do
  protected!
  @secret = APASS
  @topics = DB[:topics].all
  hsh = DB[:items].group_and_count(:topic_id)
  # hsh is zero indexed -> id-1
  hsh = hsh.map {|x| {:count=>x[:count],:topic=>@topics[x[:topic_id]-1][:name]}}
  @items_count = hsh.sort {|a,b| b[:count]<=>a[:count]}
  erb :admin
end  

# PuSH subscriber
get '/sub/:topic/?' do |topic|
  content_type 'text/plain', :charset => 'utf-8'
  exists = DB[:topics].filter(:name=>topic).first
  throw :halt, [404, "Invalid data"] unless params['hub.challenge'] and exists
  return params['hub.challenge']
end

post '/sub/:topic/?' do |topic|
  @topic = DB[:topics].filter(:name=>topic).first
  throw :halt, [404, "Invalid data"] unless @topic
  request.body.rewind
  begin
    feed = SimpleRSS.parse(request.body.read)
  rescue Exception => ex
    puts ex.to_s
  end
  throw :halt, [500, "Invalid feed"] unless feed
  feed.entries.each do |e|
    title = e.title.empty? ? e.links.first : e.title.strip_tags.strip.truncate(250)
    content = e.content || e.description || e.summary
    content = content.strip_tags.truncate(400) if content
    begin
      DB[:items].insert(:topic_id=>@topic[:id],
                        :title=>title,:content=>content,:link=>e.link,
                        :created=>Time.now)
      Pusher["chan-#{@topic[:name]}"].trigger('feed-entry', 
        {:title=>title,
         :content=>content,
         :link=>e.link,
         :created=>Time.now.utc.to_formatted_s(:rfc822)}.to_json) if USE_PUSHER
    rescue Exception => ex
      puts ex.to_s
      next
    end  
  end
  throw :halt, [200, "OK"]
end
