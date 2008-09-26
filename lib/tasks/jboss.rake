
require 'fileutils'
require 'rubygems/installer'

DEFAULT_JBOSS_HOME = File.dirname( __FILE__ ) + '/../../jboss-as-rails'

jboss_home = nil

namespace :jboss do 

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
  end

  namespace :as do
    desc "Install Rails-enabled JBoss AS 5.x"
    task :install do
      if ( File.exist?( DEFAULT_JBOSS_HOME ) )
        raise "Something exists at #{DEFAULT_JBOSS_HOME}"
      end
      exec "git clone git://github.com/bobmcwhirter/jboss-as-rails.git #{DEFAULT_JBOSS_HOME}"
    end

    desc "Run JBoss AS"
    task :'run'=>[:check] do
      jboss = JBossHelper.new( jboss_home )
      jboss.run
    end
  end


  namespace :rails do
 
    namespace :'jdbc' do 
      desc "Install needed JDBC drivers to vendor/plugins/"
      task :'install' do
        Rake::Task['jboss:rails:jdbc:install:auto'].invoke
      end

      desc "Uninstall JDBC drivers"
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
          database_yml   = YAML.load_file( "#{RAILS_ROOT}/config/database.yml" )
          db_types = []
      
          database_yml.each do |env,db_config|
            adapter = db_config['adapter']
            if ( DB_TYPES.include?( adapter ) )
              puts "WARNING: config/database.yml:#{env}: You must prefix the adapter with 'jdbc'"
              puts "    #{env}:"
              puts "        adapter: jdbc#{adapter}"
              db_types << adapter
            elsif ( adapter == 'jdbc' )
              puts "INFO: config/database.yml:#{env}: No need to use the 'jdbc' adapter"
              db_types << simple_adapter
            elsif ( adapter =~ /^jdbc(.+)/ )
              adapter = $1
              if ( DB_TYPES.include? ( adapter ) )
                db_types << adapter
              end
            else
              puts "WARNING: config/database.yml:#{env}: Unknown adapter: #{adapter}"
            end
          end
    
          db_types.uniq!
          db_types.each do |db_type|
            Rake::Task["jboss:rails:jdbc:install:#{db_type}"].invoke
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
            puts "WARNING: Gem exists; not installing: #{simple_gem_name}"
            return
          end
          puts "INFO: Installing #{gem_name}"
          Gem::Installer.new( gem_path ).unpack( "#{VENDOR_PLUGINS}/#{gem_name}" )
        end
    
        desc "Install the base activerecord-jdbc gem"
        task :install_base=>[:check] do
          db_gem = Dir["#{GEM_CACHE}/activerecord-jdbc-adapter-*.gem"].first
          install_gem_safely( db_gem )
        end
    
        DB_TYPES.keys.each do |db_type|
          desc "Install the activerecord-jdbc-#{db_type} gems"
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

    desc "Deploy this application"
    task :'deploy'=>[:check] do
      jboss = JBossHelper.new( jboss_home )
      app_dir = RAILS_ROOT
      app_name = File.basename( app_dir )
      jboss.deploy( app_name, app_dir )
    end

    desc "Undeploy this application"
    task :'undeploy'=>[:check] do
      jboss = JBossHelper.new( jboss_home )
      app_dir = RAILS_ROOT
      app_name = File.basename( app_dir )
      jboss.undeploy( app_name )
    end

    desc "Deploy or re-deploy this application"
    task :'deploy-force'=>[:check] do
      jboss = JBossHelper.new( jboss_home )
      app_dir = RAILS_ROOT
      app_name = File.basename( app_dir )
      jboss.deploy( app_name, app_dir, true )
    end
  end

end

class JBossHelper

  def initialize(jboss_home) 
    @jboss_home = jboss_home
  end

  def run()
    puts "INFO: Running JBoss AS"
    Dir.chdir(@jboss_home) do
      exec "/bin/sh bin/run.sh"
    end
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

