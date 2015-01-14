require 'mina/bundler'
require 'mina/rails'
require 'mina/git'
require 'mina/rbenv'  # for rbenv support. (http://rbenv.org)

# Basic settings:
#   domain       - The hostname to SSH to.
#   deploy_to    - Path to deploy into.
#   repository   - Git repo to clone from. (needed by mina/git)
#   branch       - Branch name to deploy. (needed by mina/git)

set :domain, 'whois-st'
set :deploy_to, '$HOME/whois'
set :repository, 'https://github.com/domify/whois' # dev
set :branch, 'master'

# staging
task :st do
  set :domain, 'whois-st'
  set :deploy_to, '$HOME/whois'
  set :repository, 'https://github.com/internetee/whois' # production
  set :branch, 'master'
end

# production
task :pr do
  set :domain, 'whois'
  set :deploy_to, '$HOME/whois'
  set :repository, 'https://github.com/internetee/whois' # production
  set :branch, 'master'
end

# Manually create these paths in shared/ (eg: shared/config/database.yml) in your server.
# They will be linked in the 'deploy:link_shared_paths' step.
set :shared_paths, [
  'config/database.yml',
  'log'
]

# Optional settings:
#   set :user, 'foobar'    # Username in the server to SSH to.
#   set :port, '30000'     # SSH port number.

# This task is the environment that is loaded for most commands, such as
# `mina deploy` or `mina rake`.
task :environment do
  # If you're using rbenv, use this to load the rbenv environment.
  # Be sure to commit your .rbenv-version to your repository.
  invoke :'rbenv:load'

  # For those using RVM, use this to load an RVM version@gemset.
  # invoke :'rvm:use[ruby-1.9.3-p125@default]'
end

# Put any custom mkdir's in here for when `mina setup` is ran.
# For Rails apps, we'll make some of the shared paths that are shared between
# all releases.
task setup: :environment do
  queue! %(mkdir -p "#{deploy_to}/shared/log")
  queue! %(chmod g+rx,u+rwx "#{deploy_to}/shared/log")

  queue! %(mkdir -p "#{deploy_to}/shared/config")
  queue! %(chmod g+rx,u+rwx "#{deploy_to}/shared/config")

  queue! %(touch "#{deploy_to}/shared/config/database.yml")
  queue %(echo '-----> Be sure to edit 'shared/config/database.yml'.')
end

desc 'Deploys the current version to the server.'
task deploy: :environment do
  deploy do
    # Put things that will set up an empty directory into a fully set-up
    # instance of your project.
    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    invoke :'bundle:install'
    to :launch do
      invoke :restart
    end
  end
end

desc 'Rolls back the latest release'
task rollback: :environment do
  queue! %(echo "-----> Rolling back to previous release for instance: #{domain}")
  queue %(ls "#{deploy_to}/releases" -Art | sort | tail -n 2 | head -n 1)
  queue! %(
    ls -Art "#{deploy_to}/releases" | sort | tail -n 2 | head -n 1 |
    xargs -I active ln -nfs "#{deploy_to}/releases/active" "#{deploy_to}/current"
  )
  to :launch do
    invoke :restart
  end
end

desc 'Restart Passenger application'
task restart: :environment do
  queue "mkdir -p #{deploy_to}/current/tmp; touch #{deploy_to}/current/tmp/restart.txt"
end
