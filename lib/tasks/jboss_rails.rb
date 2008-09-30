
namespace :jboss do 

  namespace :rails do
 
    namespace :'jdbc' do 

      DB_TYPES = { 
        "derby"=>"derby", 
        "h2"=>"h2",
        "hsqldb"=>"hsqldb", 
        "mysql"=>"mysql", 
        "postgresql"=>"postgres", 
        "sqlite3"=>"sqlite3",
      }

      VENDOR_PLUGINS = "#{RAILS_ROOT}/vendor/plugins"
    
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
    
        task :check=>[:'jboss:as:check'] do
          GEM_CACHE = "#{JBoss.jboss_home}/server/all/deployers/jboss-rails.deployer/gems/cache" unless defined?(GEM_CACHE)
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
    task :'deploy'=>[:'jboss:as:check'] do
      jboss = JBossHelper.new( JBoss.jboss_home )
      app_dir = RAILS_ROOT
      app_name = File.basename( app_dir )
      jboss.deploy( app_name, app_dir )
    end

    desc "Undeploy this application"
    task :'undeploy'=>[:'jboss:as:check'] do
      jboss = JBossHelper.new( JBoss.jboss_home )
      app_dir = RAILS_ROOT
      app_name = File.basename( app_dir )
      jboss.undeploy( app_name )
    end

    desc "Deploy or re-deploy this application"
    task :'deploy-force'=>[:'jboss:as:check'] do
      jboss = JBossHelper.new( JBoss.jboss_home )
      app_dir = RAILS_ROOT
      app_name = File.basename( app_dir )
      jboss.deploy( app_name, app_dir, true )
    end
  end

end

