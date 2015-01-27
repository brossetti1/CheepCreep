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

#user "/followers" or "/following", read Github API docs for endpoint references.
  def get_users(user, follow_type)
    resp = self.class.get("/users/#{user}#{follow_type}")
    json = JSON.parse(resp.body)
    binding.pry
    users = json.shuffle[0..20]
    users_array = []
    users.each do |user|
      users_array << get_user(user['login'])
    end
    users_array
  end

  def get_user(user)
    hsh = Hash.new(0)
    resp = self.class.get("/users/#{user}")
    json = JSON.parse(resp.body)
    hsh[:login] =         json['login']
    hsh[:name] =          json['name']
    hsh[:blog] =          json['blog']
    hsh[:public_repos] =  json['public_repos']
    hsh[:followers] =     json['followers']
    hsh[:following] =     json['following']
    hsh
  end

  def push_assoc_users_to_a(user)
    users_array = []
    current_user = get_user(user)
    user_following = get_users(user,'/following')
    user_followers = get_users(user,'/followers')
    users_array.push(current_user, user_following, user_followers).flatten!
    users_array
  end

  #def get_gist(username = brit)
  #  resp = self.class.get("/users/#{username}/gists")
  #  json = JSON.parse(resp)
  #end

end

def add_users_to_db(user)
  github = Github.new()
  users = github.push_assoc_users_to_a(user)
  users.each do |user|
    CheepCreep::GithubUser.create(user)
  end
end



#github_username: apitestfun password: ironyard1
#get, change, add, or delete gists



