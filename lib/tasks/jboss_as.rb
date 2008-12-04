

DEFAULT_JBOSS_HOME = File.dirname( __FILE__ ) + '/../../jboss-as-rails'

module JBoss
  def self.jboss_home
    return @jboss_home
  end

  def self.jboss_home=(jboss_home)
    @jboss_home=jboss_home
  end
end

namespace :jboss do 
  namespace :as do
    desc "Check for JBOSS_HOME"
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
        raise "No JBOSS_HOME.  Try 'rake jboss:install-as-rails'"
      end

      JBoss.jboss_home=jboss_home
    end
    
    desc "Check for vendor/rails"
    task :'check_vendored_rails' do
     vendor_rails = File.exist?("#{RAILS_ROOT}/vendor/rails")
     raise "Rails must be frozen to run from JBoss.  Try 'rake rails:freeze:gems'" unless vendor_rails
    end

    desc "Run JBoss AS"
    task :'run'=>[:check] do
      jboss = JBossHelper.new( JBoss.jboss_home )
      jboss.run
    end

=begin
    namespace :run do
      desc "Run JBoss AS in a local cluster"
      task :'cluster'=>[:'jboss:as:check'] do
        jboss = JBossHelper.new( JBoss.jboss_home )
        jboss.run_cluster
      end
    end
=end
  end


end

class JBossHelper

  def initialize(jboss_home) 
    @jboss_home = jboss_home
  end

  def run()
    puts "INFO: Running JBoss AS"
    Dir.chdir(@jboss_home) do
      exec "/bin/sh bin/run.sh -c default"
    end
  end

  def run_cluster()
    puts "INFO: Running JBoss AS cluster"
    cmd = "jruby #{File.dirname( __FILE__ )}/../../bin/start_local_cluster.rb 127.0.0.10 3'"
    exec cmd
  end

  def deploy(app_name, rails_root, force=false)
    deployment = deployment_name( app_name )
    if ( File.exist?( deployment ) ) 
      if ( force )
        puts "INFO: forcing redeploy: #{app_name}"
        FileUtils.touch( deployment )
        return
      else
        puts "ERROR: already deployed: #{app_name}; not deploying."
        return
      end
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
      puts "WARNING: not currently deployed: #{app_name}"
      return
    end

    File.delete( deployment )

    puts "INFO: undeployed #{app_name}"
  end

  def deployment_name(app_name) 
    "#{@jboss_home}/server/default/deploy/#{app_name}-rails.yml" 
  end

end

