
DEFAULT_JBOSS_HOME = File.dirname( __FILE__ ) + '/../../jboss-as-rails'

jboss_home = nil

namespace :jboss do 

  task :'check' do
    jboss_home = ENV['JBOSS_HOME']

    ( jboss_home = jboss_home.strip) unless ( jboss_home.nil? )
    ( jboss_home = nil ) if ( jboss_home == '' )
  
    if ( jboss_home.nil? )
      if ( File.exist?( DEFAULT_JBOSS_HOME ) ) 
        jboss_home = DEFAULT_JBOSS_HOME
      end
    end
  
    if ( jboss_home.nil? )
      raise "No JBOSS_HOME.  Try 'rake jboss:install'"
    end

    puts "JBOSS_HOME ... #{jboss_home}"
  end

  task :'install' do 
    if ( File.exist?( DEFAULT_JBOSS_HOME ) )
      raise "Something exists at #{DEFAULT_JBOSS_HOME}"
    end
    exec "git clone git://github.com/bobmcwhirter/jboss-as-rails.git #{DEFAULT_JBOSS_HOME}"
  end

  task :'run'=>[:check] do
    puts "starting jboss-as-rails"
    jboss = JBossHelper.new( jboss_home )
    jboss.run
  end

  task :'run-clean' do
    puts "starting jboss-as-rails cleanly"
    jboss = JBossHelper.new( jboss_home )
    jboss.undeploy_all
    jboss.run
  end

  task :'deploy'=>[:check] do
    jboss = JBossHelper.new( jboss_home )
    app_dir = RAILS_ROOT
    app_name = File.basename( app_dir )
    jboss.deploy( app_name, app_dir )
    
  end

  task :'undeploy'=>[:check] do
    jboss = JBossHelper.new( jboss_home )
    app_dir = RAILS_ROOT
    app_name = File.basename( app_dir )
    jboss.undeploy( app_name )
  end

  task :'undeploy-all' do
    puts "undeploying all rails applications"
    jboss = JBossHelper.new( jboss_home )
    jboss.undeploy_all
  end


end

class JBossHelper

  def initialize(jboss_home) 
    @jboss_home = jboss_home
  end

  def run()
    puts "running JBoss"
    Dir.chdir(@jboss_home) do
      #exec "java -server -jar bin/run.jar"
      exec "/bin/sh bin/run.sh"
    end
  end

  def deploy(app_name, rails_root)
    deployment = deployment_name( app_name )
    if ( File.exist?( deployment ) ) 
      puts "ERROR: already deployed: #{app_name}"
      return
    end

    deployment_descriptor = {
      'application' => {
        'RAILS_ROOT'=>rails_root,
        'RAILS_ENV'=>RAILS_ENV,
      },
      'web' => {
        'context'=>'/'
      }
    }

    File.open( deployment, 'w' ) do |file|
      YAML.dump( deployment_descriptor, file )
    end
    puts "INFO: deployed: #{app_name}"
  end

  def undeploy(app_name) 
    deployment = deployment_name( app_name )
    if ( ! File.exist?( deployment ) )
      puts "WARNING: not deployed: #{app_name}"
      return
    end

    File.delete( deployment )

    puts "INFO: undeployed #{app_name}"
  end

  def undeploy_all()
    puts "undeploying all deployments"
  end

  def deployment_name(app_name) 
    "#{@jboss_home}/server/default/deploy/#{app_name}-rails.yml" 
  end

end

