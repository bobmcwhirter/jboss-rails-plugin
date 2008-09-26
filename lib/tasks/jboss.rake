
require 'fileutils'
require 'rubygems/installer'

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
      raise "No JBOSS_HOME.  Try 'rake jboss:install-as-rails'"
    end

    puts "JBOSS_HOME ... #{jboss_home}"
  end


  namespace :'jdbc' do 
    task :'install' do
      Rake::Task['jboss:jdbc:install:auto'].invoke
    end
    task :'uninstall'=>[:check] do
      files = Dir["#{VENDOR_PLUGINS}/activerecord-jdbc*"] + Dir["#{VENDOR_PLUGINS}/jdbc-*"]
      for file in files
        FileUtils.rm_rf( file )
      end
    end
    namespace :'install' do

      DB_TYPES = { 
        "derby"=>"derby", 
        "h2"=>"h2",
        "hsqldb"=>"hsqldb", 
        "mysql"=>"mysql", 
        "postgresql"=>"postgres", 
        "sqlite3"=>"sqlite3",
      }
      VENDOR_PLUGINS = "#{RAILS_ROOT}/vendor/plugins"
  
      task :'auto'=>[:check] do
        puts "doing magic install"
        database_yml   = YAML.load_file( "#{RAILS_ROOT}/config/database.yml" )
        db_types = []
    
        database_yml.each do |env,db_config|
          adapter = db_config['adapter']
          if ( DB_TYPES.include?( adapter ) )
            db_types << adapter
          elsif ( adapter == 'jdbc' )
            puts "config/database.yml:#{env}: No need to use the 'jdbc' adapter"
          elsif ( adapter =~ /^jdbc(.*)$/ )
            simple_adapter = $1
            puts "config/database.yml:#{env}: No need to use the 'jdbc' prefix.  Change #{adapter} to #{simple_adapter}"
            db_types << simple_adapter
          else
            puts "config/database.yml:#{env}: Unknown adapter: #{adapter}"
          end
        end
  
        db_types.uniq!
        db_types.each do |db_type|
          # puts "installing: #{db_type}"
          Rake::Task["jboss:jdbc:install:#{db_type}"].invoke
        end
      end
  
      task :check=>[:'jboss:check'] do
        GEM_CACHE = "#{jboss_home}/server/default/deployers/jboss-rails.deployer/gems/cache" unless defined?(GEM_CACHE)
      end
  
      def install_gem_safely(gem_path)
        gem_name = File.basename( gem_path, ".gem" )
        simple_gem_name = File.basename( gem_path )
        simple_gem_name = simple_gem_name.gsub( /-([0-9]+\.)+gem$/, '' )
    
        existing = Dir[ "#{VENDOR_PLUGINS}/#{simple_gem_name}-*" ]
        unless ( existing.empty? )
          puts "Gem exists; not installing: #{simple_gem_name}"
          return
        end
        puts "Installing #{gem_name}"
        Gem::Installer.new( gem_path ).unpack( "#{VENDOR_PLUGINS}/#{gem_name}" )
      end
  
      task :install_base=>[:check] do
        db_gem = Dir["#{GEM_CACHE}/activerecord-jdbc-adapter-*.gem"].first
        install_gem_safely( db_gem )
      end
  
      DB_TYPES.keys.each do |db_type|
        task db_type.to_sym=>[:install_base] do
          glob = "#{GEM_CACHE}/jdbc-#{db_type}-*.gem"
          db_gems = Dir["#{GEM_CACHE}/activerecord-jdbc#{db_type}-adapter-*.gem"]
          if ( DB_TYPES[db_type] != nil )
            db_gems += Dir["#{GEM_CACHE}/jdbc-#{DB_TYPES[db_type]}-*.gem"]
          end
          db_gems.each do |db_gem|
            install_gem_safely( db_gem )
          end
        end
      end
    end
  end

  task :'install-as-rails' do 
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

  task :'deploy-force'=>[:check] do
    jboss = JBossHelper.new( jboss_home )
    app_dir = RAILS_ROOT
    app_name = File.basename( app_dir )
    jboss.deploy( app_name, app_dir, true )
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

  def deploy(app_name, rails_root, force=false)
    deployment = deployment_name( app_name )
    if ( File.exist?( deployment ) ) 
      if ( force )
        FileUtils.touch( deployment )
        puts "INFO: forcing redeploy: #{app_name}"
        return
      else
        puts "ERROR: already deployed: #{app_name}"
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

