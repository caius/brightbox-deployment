#  Brightbox - Easy Ruby Web Application Deployment
#  Copyright (C) 2008, Brightbox Systems
#  Written by Neil Wilson <neil@brightbox.co.uk>
#
#  This file is part of the Brightbox deployment system
#
#

def execute_on_one_line(cmd_list)
  cmd_list.gsub!(/\n/m, ' ')
  invoke_command cmd_list, :via => fetch(:run_method, :sudo)
end

def monit_setup
  "/usr/bin/brightbox-monit"
end
depend :remote, :command, monit_setup

def apache_setup
  "/usr/bin/brightbox-apache"
end
depend :remote, :command, apache_setup

def mongrel_setup
  "/usr/bin/brightbox-mongrel"
end
depend :remote, :command, mongrel_setup

def logrotate_setup
  "/usr/bin/brightbox-logrotate"
end
depend :remote, :command, logrotate_setup

def known_hosts_setup
  "/usr/bin/brightbox-ssh"
end
depend :remote, :command, known_hosts_setup

namespace :configure do

  desc %Q{
  [internal]Create Apache config. Creates a load balancing virtual host \
  configuration based upon your specified settings

    :application      Name of the application
    :domain           Domain name which will point to the application
    :domain_aliases   Comma separated list of aliased for the main domain
    :mongrel_host     Name of application layer host (default localhost)
    :mongrel_port     Start port of the mongrel cluster (default 8000)
    :mongrel_servers  Number of servers on app host (default 2)

  }
  task :apache, :roles => :web, :except => {:no_release => true} do
    execute_on_one_line <<-END
        #{apache_setup}
        -n #{application}
        -d #{domain}
        -a '#{domain_aliases}'
        -w #{File.join(current_path, 'public')}
        -h #{mongrel_host}
        -p #{mongrel_port}
        -s #{mongrel_servers}
    END
  end

  desc %Q{
  [internal]Create Mongrel config. Creates a set of mongrels running \
  on the specified ports of the application server(s).

    :application      Name of the application
    :mongrel_host     Name of application layer host (default localhost)
    :mongrel_port     Start port of the mongrel cluster (default 8000)
    :mongrel_servers  Number of servers on app host (default 2)
    :mongrel_pid_file The name of the file containing the mongrel PID 

  }
  task :mongrel, :roles => :app, :except => {:no_release => true} do
    execute_on_one_line <<-END
        #{mongrel_setup}
        -n #{application}
        -r #{current_path}
        -p #{mongrel_port}
        -s #{mongrel_servers}
        -h #{mongrel_host}
        -C #{mongrel_config_file}
        -P #{mongrel_pid_file}
    END
  end

  desc %Q{
  [internal]Create Monit config. Build a monit configuraton file \
  to look after this application

    :application      Name of the application
    :mongrel_host     Name of application layer host (default localhost)
    :mongrel_port     Start port of the mongrel cluster (default 8000)
    :mongrel_servers  Number of servers on app host (default 2)

  }
  task :monit, :except => {:no_release => true} do
    execute_on_one_line <<-END
        #{monit_setup}
        -n #{application}
        -r #{current_path}
        -h #{mongrel_host}
        -p #{mongrel_port}
        -s #{mongrel_servers}
        -C #{mongrel_config_file}
        -P #{mongrel_pid_file}
    END
  end

  desc %Q{
  [internal]Create logrotation config. Build a logrotate configuraton file \
  so that logrotate will look after the log files.

    :application      Name of the application
    :log_max_size     Rotate when log reaches this size
    :log_keep         Number of compressed logs to keep

  }
  task :logrotation, :roles => :app, :except => {:no_release => true} do
    execute_on_one_line <<-END
        #{logrotate_setup}
        -n #{application}
        -l #{log_dir}
        -s #{log_max_size}
        -k #{log_keep}
    END
  end

  desc %Q{
  [internal]Run the check command if this application hasn't been
  deployed yet
  }
  task :check, :except => {:no_release => true} do
    begin
      deploy.check unless releases.length > 0
    rescue
      puts "Error detected. Have you run 'cap deploy:setup'?"
      raise
    ensure
      reset! :releases
    end
  end

  desc %Q{
  [internal]Make sure that SSH can loopback on the server name.
  }
  task :known_hosts, :except => {:no_release => true} do
    run known_hosts_setup
  end

end