require 'launchy'
require 'oauth'
require 'yaml'
require 'rest-client'
require 'json'
require 'addressable/uri'
require 'nokogiri'
require './secrets.rb'

CONSUMER = OAuth::Consumer.new(
  CONSUMER_KEY, CONSUMER_SECRET, :site => "https://twitter.com")

class User
  attr_reader :username
  def initialize(username)
    @username = username
  end

	def statuses
    puts "Please enter a username"
    username = gets.chomp
    statuses_uri = Addressable::URI.new(
       :scheme => "https",
       :host => "api.twitter.com",
       :path => "/1.1/statuses/user_timeline.json",
       :query_values => {:screen_name => username, :count => 10}).to_s
    statuses = JSON.parse(self.access_token.get(statuses_uri).body)
    print_statuses(statuses)
  end

  def print_statuses(statuses)
    statuses.each do |status|
      puts status["user"]["screen_name"]
      puts status["created_at"]
      puts status["text"]
      puts ""
    end
  end
end

class EndUser < User
  def initialize(username)
    super(username)
    login
  end

  def access_token
    @@access_token
  end

  def display_menu
    puts "What would you like to do?"
    puts "1. tweet"
    puts "2. dm"
    puts "3. see timeline"
    puts "4. see another user's tweets"
    puts "5. exit"
  end

  def menu
    while true
      display_menu
      selection = gets.chomp.to_i

      case selection
      when 1
        tweet
      when 2
        dm
      when 3
        print_timeline
      when 4
        statuses
      when 5
        break
      end
    end
  end

  def login
    @@access_token = get_token('token_file.txt')
  end

  def tweet
    puts "What do you want to say?"
    message = gets.chomp
    status = Status.new(self)
    status.tweet(message)
  end

  def dm
    puts "Who do you want to DM?"
    target_user = gets.chomp

    puts "What do you want to say?"
    message = gets.chomp

    status = Status.new(self)
    status.dm(target_user, message)
  end

  def get_token(token_file)
    if File.exist?(token_file)
      access_token = File.open(token_file) { |f| YAML.load(f) }
    else
      access_token = request_access_token
      File.open(token_file, "w") { |f| YAML.dump(access_token, f) }
    end

    access_token
  end

  def request_access_token
    request_token = CONSUMER.get_request_token
    authorize_url = request_token.authorize_url
    puts "Go to this URL: #{authorize_url}"
    # launchy is a gem that opens a browser tab for us
    Launchy.open(authorize_url)
    puts "Login, and type your verification code in"
    oauth_verifier = gets.chomp

    access_token = request_token.get_access_token(
        :oauth_verifier => oauth_verifier)
  end

  def get_user_timeline
    timeline_uri = Addressable::URI.new(
       :scheme => "https",
       :host => "api.twitter.com",
       :path => "1.1/statuses/home_timeline.json").to_s
    @@access_token.get(timeline_uri).body
  end

  def print_timeline
    timeline = JSON.parse(get_user_timeline)

    timeline.each do |tweet|
      name = tweet["user"]["name"]
      screen_name = tweet["user"]["screen_name"]
      tweet_text = tweet["text"]
      puts "#{name} (@#{screen_name}): #{tweet_text}"
      print "\n"
    end
  end
end

class Status
  def initialize(end_user)
    @end_user = end_user
  end

  def user
    @end_user.username
  end

  def tweet(message)
    status_uri = Addressable::URI.new(
       :scheme => "https",
       :host => "api.twitter.com",
       :path => "/1.1/statuses/update.json").to_s
    @end_user.access_token.post(status_uri, {:status => message})
  end

  def dm(screen_name, message)
    status_uri = Addressable::URI.new(
         :scheme => "https",
         :host => "api.twitter.com",
         :path => "1.1/direct_messages/new.json").to_s
    @end_user.access_token.post(status_uri,
        {:text => message, :screen_name => "#{screen_name}"})
  end
end

EndUser.new("eanhuddleston").menu
