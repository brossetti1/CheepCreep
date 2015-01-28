require "cheepcreep/version"
require "cheepcreep/init_db"
require "httparty"
require "pry"

# GITHUB_USER=apitestfun GITHUB_PASS=ironyard1 bundle exec ruby lib/cheepcreep.rb
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

#user "/followers" or "/following" 
#read Github API docs for endpoint references for 'users' queries.
  def get_users(user, follow_type='followers')
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

  #Remember that you'll need to call .to_json on the value of :body
  #[post_body]: http://www.rubydoc.info/github/jnunemaker/httparty -->
  #/HTTParty/ClassMethods#post-instance_method

  #[list-gists]: https://developer.github.com/v3/gists/#list-gists
  def list_gists(user, opts={})
    options = {:body => opts}
    resp = self.class.get("/users/#{user}/gists", options)
    json = JSON.parse(resp.body)
  end

  def starred?(id)
    starred = self.class.get("/gists/#{id}/star")
    starred.code == 204 ? :true : :false
  end

  def select_gist_id(function_call, user=ENV['GITHUB_USER'])
    begin
      gists = list_gists(user)
      puts "user: #{gists[0]['owner']['login']}"
    rescue NoMethodError
      puts "\n\nTHERE ARE NO MORE GISTS TO #{function_call.upcase}\n\n"
      return
    end
    gists.each_with_index do |gist, i| 
      puts "#{i+1}) gist name: #{gist['files'].keys[0]}, 
      gist id: #{gist['id']},
      starred: #{starred?gist['id']}\n\n"
    end 
    puts "\n\nwhich gist would you like to #{function_call}?"
    index = gets.chomp.to_i - 1
    id = gists[index]['id']
    name = gists[index]['files'].keys[0]
    [id, name]
  end

  #The **Create** and **Edit** methods are a bit tricky. Do them last.
  #In particular, you'll want their methods to take a file path and
  #put its contents into the gist files array with [File.read][file-read]
  #[file-read]: http://ruby.bastardsbook.com/chapters/io/

  #[create-gist]: https://developer.github.com/v3/gists/#create-a-gist
  def create_gist(filepath, opts={})
    #can pass description => "text", public => boolean to opts
    f = File.open(filepath, 'r')
    file_name = File.basename(f)
    content = f.read
    inline_opts = {'files' => {file_name => {'content' => content}}}
    opts = inline_opts.merge(opts)
    options = {:body => opts.to_json}
    resp = self.class.post("/gists", options)
    resp.code == 201 ? response = "successfully created gist, #{file_name}." : response = "could not create the gist, #{file_name}"
    puts response
  end
  #[edit-gist]: https://developer.github.com/v3/gists/#edit-a-gist
  def edit_gist(filepath, opts = {})
    id, name = select_gist_id("delete")
    options = {:body => opts}
    response = self.class.patch("/gists/#{id}")
  end

  #[delete-gist]: https://developer.github.com/v3/gists/#delete-a-gist
  def delete_gist
    id, name = select_gist_id("delete")
    resp = self.class.delete("/gists/#{id}")
    resp.code == 204 ? response = "\nThe gist, #{name}, has been deleted\n" : response = "\nthere was a problem deleting the gist, #{name}.\n"
    puts response
  end

  #[star-a-gist]: https://developer.github.com/v3/gists/#star-a-gist
  def star_gist(user)
    id, name = select_gist_id("star", user)
    resp = self.class.put("/gists/#{id}/star")
    resp.code == 204 ? respones =  "The gist, #{name}, has been starred" : response = "there was a problem starring the gist, #{name}"
    puts response
  end

  #[unstar-a-gist]: https://developer.github.com/v3/gists/#unstar-a-gist
  def unstar_gist(user)
    id, name = select_gist_id("star", user)
    resp = self.class.delete("/gists/#{id}/star")
    respo.code == 204 ? respones =  "The gist, #{name}, has been unstarred" : response = "there was a problem unstarring the gist, #{name}"
    puts response
  end
end

def add_users_to_db(user)
  github = Github.new()
  users = github.push_assoc_users_to_a(user)
  users.each do |user|
    CheepCreep::GithubUser.create(user)
  end
end

#pass either :
def show_users_ordered_by(query)
  CheepCreep::GithubUser.order(query).reverse.each do |u|
    puts "login: #{u.login}, name: #{u.name}, followers: #{u.followers}, public repos #{u.public_repos}"
  end
end 



binding.pry


## Hard Mode
#Disconnect the Wifi or stop doing basic authentication and run your rate limit out.
#How does your Client handle failure?
#Improve this with a combination of status code checks and exception handling with `rescue`.
##

#github_username: apitestfun password: ironyard1
#get, change, add, or delete gists

#[restful]: http://restful-api-design.readthedocs.org/en/latest/methods.html
#[rants]: http://williamdurand.fr/2014/02/14/please-do-not-patch-like-an-idiot/

