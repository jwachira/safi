Capistrano::Configuration.instance(:must_exist).load do
  
  #finalizing deploy is normal behaviour but in some (multi-server) environments we don't want that.
  _cset :finalize_deploy, true
  
  namespace :deploy do
    desc "Deploy the app"
    task :default, :roles => [:app] do
      update
      restart
    end
    
    desc "Create shared dirs"
     task :setup_dirs, :roles => :app, :except => { :no_release => true } do
       commands = shared_dirs.map do |path|
         "mkdir -p #{shared_path}/#{path}"
       end
       run commands.join(" && ")
     end
     

    desc "Setup a GitHub-style deployment."
    task :setup, :roles => [:app], :except => { :no_release => true } do
      run "rm -rf #{current_path}"
      setup_dirs
      run "cd #{deploy_to} && git clone #{repository} #{current_path}"
    end

    task :update do
      transaction do
        update_code
      end
    end
    
    desc "Deploy it, github-style."
    task :default, :roles => :app, :except => { :no_release => true } do
      update
      restart
    end
    
    desc "Destroys everything"
    task :seppuku, :roles => :app, :except => { :no_release => true } do
      run "rm -rf #{current_path}; rm -rf #{shared_path}"
    end
    
    desc "Alias for symlinks:make"
    task :symlink, :roles => :app, :except => { :no_release => true } do
      symlinks.make
    end
    
    desc "Remote run for rake db:migrate"
    task :migrate, :roles => :app, :except => { :no_release => true } do
      run "cd #{current_path}; bundle exec rake RAILS_ENV=#{rails_env} db:migrate"
    end

    desc "Update the deployed code."
    task :update_code, :roles => [:app], :except => { :no_release => true } do
      run "cd #{current_path}; git fetch origin; git reset --hard origin/#{branch}; git submodule update --init"
      if fetch(:finalize_deploy, true) 
        finalize_update
      end
    end
    
    desc "Update the database (overwritten to avoid symlink)"
    task :migrations do
      transaction do
        update_code
      end
      migrate
    end
    
    
    # "rollback" is actually a namespace with a default task
    # we overwrite the default task below to get our new behavior
    namespace :rollback do
      desc "Moves the repo back to the previous version of HEAD"
      task :repo, :except => { :no_release => true }, :roles => [:app, :worker] do
        set :branch, "HEAD@{1}"
        deploy.default
      end

      desc "Rewrite reflog so HEAD@{1} will continue to point to at the next previous release."
      task :cleanup, :except => { :no_release => true }, :roles => [:app, :worker] do
        run "cd #{current_path}; git reflog delete --rewrite HEAD@{1}; git reflog delete --rewrite HEAD@{1}"
      end

      desc "Rolls back to the previously deployed version."
      task :default do
        rollback.repo
        rollback.cleanup
      end
    end
    
  end
  
  #############################################################
  # Set Rake Path
  #############################################################

  namespace :deploy do
    desc "Set rake path"
    task :set_rake_path, :roles => [:app, :worker] do
      run "which rake" do |ch, stream, data|
        if stream == :err
          abort "captured output on STDERR when setting rake path: #{data}"
        elsif stream == :out
          set :rake_path, data.to_s.strip
        end
      end
    end
  end
  

  # Turn of capistrano's restart in favor of passenger restart
  namespace :deploy do
    desc "Remove deploy:restart In Favor Of passenger:restart Task"
    task :restart do
    end
  end
  
end