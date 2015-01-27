require "cheepcreep/version"
require "cheepcreep/init_db"
require "httparty"
require "pry"

module CheepCreep
  class GithubUser < ActiveRecord::Base
    validates :login, :uniqueness => true, :presence => true
  end
end

class Github
  attr_reader :auth
  include HTTParty
  base_uri 'https://api.github.com'
  basic_auth ENV['GITHUB_USER'], ENV['GITHUB_PASS']

  def get_followers(user = 'redline6561')
    resp = self.class.get("/users/#{user}/followers")
    json = JSON.parse(resp.body)
    user_followers = json.shuffle[0..20]
    followers_array = []
    user_followers.each do |user|
      followers_array << get_user(user['login'])
    end
    followers_array
  end

  def get_following(user = 'redline6561')
    resp = self.class.get("/users/#{user}/following")
    users_following = resp.shuffle[0..20]
    following_array = []
    users_following.each do |user|
      following_array << get_user(user['login'])
    end
    following_array
  end

  #def get_users(user = 'redline6561', follow_type = '')
  #  resp = self.class.get("/users/#{user}/#{follow_type}")
  #  users_following = resp.shuffle[0..20]
  #  users_array = []
  #  users_array.each do |user|
  #    users_array << get_user(user['login'])
  #  end
  #  users_array
  #end

  def get_user(user = 'redline6561', opts={})
    opts.merge!({:basic_auth => @auth})
    hsh = Hash.new(0)
    resp = self.class.get("/users/#{user}", opts)
    json = JSON.parse(resp.body)
    hsh[:login] =         json['login']
    hsh[:name] =          json['name']
    hsh[:blog] =          json['blog']
    hsh[:public_repos] =  json['public_repos']
    hsh[:followers] =     json['followers']
    hsh[:following] =     json['following']
    hsh
  end

  def push_assoc_users_to_a(user = 'redline6561')
    users_array = []
    current_user = get_user(user)
    user_following = get_following(user)
    user_followers = get_followers(user)
    users_array.push(current_user, user_following, user_followers).flatten!
    users_array
  end

  #def get_gist(username = brit)
  #  resp = self.class.get("/users/#{username}/gists")
  #  json = JSON.parse(resp)
  #end

end

binding.pry

github = Github.new()
users = github.push_assoc_users_to_a('redline6561')#.flatten!


users.each do |user|
  CheepCreep::Github.create(login:        user[:login],
                            name:         user[:name],
                            blog:         user[:blog],
                            public_repos: user[:public_repos],
                            followers:    user[:followers],
                            following:    user[:following])
end

users.each do |user|
  CheepCreep::Github.create(user)
end

#github_username: testapifun password: Ironyard
#get, change, add, or delete gists



