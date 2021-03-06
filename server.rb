require 'sinatra'
require 'json'
require 'pathname'
require 'git'
require 'pp'

module StaticViewer
  class Server < Sinatra::Base
    #use Rack::Auth::Basic, "Restricted Area" do |username, password|
    #  username == ENV['AUTH_USENAME'] and password == ENV['AUTH_PASSWORD']
    #end
    use Rack::Access, {
      '/' => ENV['ALLOW_IPS'].split(',')
    } if ENV['ALLOW_IPS']

    set :slim, layout: :application

    get '/' do
      @repos = Dir.chdir("#{settings.root}/repos") { Dir.glob("*") }

      slim :index
    end

    get '/repos/:name' do
      working_dir = "#{settings.root}/repos/#{params[:name]}"
      @g = Git.open(working_dir, log: nil)
      tree = { name: params[:name], children: tree(working_dir) }
      @tree = JSON.dump(tree)

      slim :repos
    end

    post '/repos' do
      url = params[:url]
      name = params[:name]
      g = Git.clone(url, name, path: "#{settings.root}/repos/")

      redirect '/'
    end

    post '/repos/:name/pull' do
      working_dir = "#{settings.root}/repos/#{params[:name]}"
      g = Git.open(working_dir, log: nil)
      g.checkout
      g.fetch('origin', { p: true })
      g.merge("origin/#{g.current_branch}")

      redirect "/repos/#{params[:name]}"
    end

    post '/repos/:name/checkout' do
      working_dir = "#{settings.root}/repos/#{params[:name]}"
      g = Git.open(working_dir, log: nil)
      g.checkout

      if params[:branch] != "master" && !params[:branch].start_with?("HEAD") && g.is_local_branch?(params[:branch])
        g.branch(params[:branch]).delete
      end
      g.checkout(params[:branch])

      redirect "/repos/#{params[:name]}"
    end

    get "/views/repos/:name/*" do
      file = "#{settings.root}/repos/#{params[:name]}/#{params[:splat].first}"
      if File.exist?(file)
        send_file(file)
      else
        slim :"404"
      end
    end

    private
    def tree(path)
      data = []
      Dir.entries(path).sort.each do |entry|
        next if entry.start_with?('.')

        child = {}
        full_path = File.join(path, entry)
        if File.directory?(full_path)
          child[:children] = tree(full_path)
        end

        child[:name] = entry
        child[:full] = Pathname(full_path).relative_path_from(Pathname(settings.root))
        data << child
      end
      data
    end
  end
end
