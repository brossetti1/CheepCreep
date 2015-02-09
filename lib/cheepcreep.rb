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

#follow_type can be "followers" or "following" as of 1/29/2015
#read Github API docs for endpoint references for 'users' queries.
  def get_users(user, follow_type='followers', opts={})
    resp = self.class.get("/users/#{user}/#{follow_type}", {:query=>opts})
    json = JSON.parse(resp.body)
    json.each {|user| get_user(user['login'])}
  end

  def get_user(user)
    resp = self.class.get("/users/#{user}")
    json = JSON.parse(resp.body)
  end

  #[list-gists]: https://developer.github.com/v3/gists/#list-gists
  def list_gists(user, opts={})
    options = {:query => opts}
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
      puts "\n\nTHERE ARE NO GISTS TO #{function_call.upcase}\n\n"
      return
    end
    gists.each_with_index do |gist, i| 
      puts "#{i+1}) gist name: #{gist['files'].keys[0]}, 
      gist id: #{gist['id']},
      starred: #{starred?(gist['id'])}\n\n"
    end 
    puts "\n\nwhich gist would you like to #{function_call}?"
    index = gets.chomp.to_i - 1
    id = gists[index]['id']
    name = gists[index]['files'].keys[0]
    [id, name]
  end

  def generate_options(filepath, opts={})
    File.open(filepath, 'r') do |f|
      name = File.basename(f)
      content = f.read
      inline_opts = {'files' => {name => {'content' => content}}}
      options = inline_opts.merge(opts)
      return [options, name]
    end
  end

  def response_handling(resp, return_code, gist_name, function_call)
    resp.code == return_code ? response =  "The gist, #{gist_name}, has been successfully #{function_call}" : response = "there was a problem processing the request, the gist, #{name}, was NOT #{function_call}"
    puts response
  end

  #[create-gist]: https://developer.github.com/v3/gists/#create-a-gist
  #test file path => /Users/brianrossetti/Programming/testrubybuild/ProgrammingRuby/IronYard/cheepcreep/gists/
  #can pass 'description' => "text", 'public' => boolean to opts
  def create_gist(filepath, opts={})
    begin
      create_opts, name = generate_options(filepath, opts)
      options = {:body => create_opts.to_json}
      resp = self.class.post("/gists", options)
      response_handling(resp, 201, name, "created")
    rescue SocketError => e
      puts "\ncould not connect to Github, heres the error - SocketError - #{e}\n"
      puts "your probably not connected to the internetz, dumbo"
    end
  end
  
  #can pass 'description' => "text", 'filename' => "text.ext"
  #[edit-gist]: https://developer.github.com/v3/gists/#edit-a-gist
  def edit_gist(filepath, opts = {})
    begin
      id, name = select_gist_id("edit")
      edit_opts = generate_options(filepath, opts)[0]
      options = {:body => edit_opts.to_json}
      resp = self.class.patch("/gists/#{id}", options)
      response_handling(resp, 200, name, "edited")
    rescue SocketError => e
      puts "\ncould not connect to Github, heres the error - SocketError - #{e}\n"
      puts "your probably not connected to the internetz, dumbo"
    end
  end

  #[delete-gist]: https://developer.github.com/v3/gists/#delete-a-gist
  def delete_gist
    begin
      id, name = select_gist_id("delete")
      resp = self.class.delete("/gists/#{id}")
      response_handling(resp, 204, name, "deleted")
    rescue SocketError => e
      puts "\ncould not connect to Github, heres the error - SocketError - #{e}\n"
      puts "your probably not connected to the internetz, dumbo"
    end
  end

  #[star-a-gist]: https://developer.github.com/v3/gists/#star-a-gist
  def star_gist(user)
    begin
      id, name = select_gist_id("star", user)
      resp = self.class.put("/gists/#{id}/star")
      response_handling(resp, 204, name, "starred")
    rescue SocketError => e
      puts "\ncould not connect to Github, heres the error - SocketError - #{e}\n"
      puts "your probably not connected to the internetz, dumbo"
    end
  end

  #[unstar-a-gist]: https://developer.github.com/v3/gists/#unstar-a-gist
  def unstar_gist(user)
    begin
      id, name = select_gist_id("unstar", user)
      resp = self.class.delete("/gists/#{id}/star")
      response_handling(resp, 204, name, "unstarred")
    rescue SocketError => e
      puts "\ncould not connect to Github, heres the error - SocketError - #{e}\n"
      puts "your probably not connected to the internetz, dumbo"
    end
  end
end


def add_to_db(users)
  users.sample(20).each do |user|
    CheepCreep::GithubUser.create(user['login'],
                                  user['name'],
                                  user['blog'],
                                  user['public_repos'],
                                  user['followers'],
                                  user['following'])
  end
end

def show_users_ordered_by(query="followers")
  CheepCreep::GithubUser.order(query).reverse.each do |u|
    puts "login: #{u.login}, name: #{u.name}, followers: #{u.followers}, public repos #{u.public_repos}"
  end
end 

def populate_users(user,follow_type)
  github = Github.new()
  users = github.get_users(user,follow_type)
  add_to_db(users)
end

binding.pry


## Hard Mode
#Disconnect the Wifi or stop doing basic authentication and run your rate limit out.
#How does your Client handle failure?
#Improve this with a combination of status code checks and exception handling with `rescue`.
##

#[restful]: http://restful-api-design.readthedocs.org/en/latest/methods.html
#[rants]: http://williamdurand.fr/2014/02/14/please-do-not-patch-like-an-idiot/

