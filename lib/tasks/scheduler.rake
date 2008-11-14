
require 'find'

namespace :jboss do
  namespace :scheduler do
    namespace :run do
      scheduler_path = "#{RAILS_ROOT}/app/scheduler"
  
      Find.find( scheduler_path ) do |path|
        if ( path =~ /.*\.rb$/ ) 
          task_path = path[ scheduler_path.length+1..-1 ]
          base_name = File.basename( task_path, '.rb' )
          class_path = task_path[0..-4]
  
          desc "Run #{class_path.camelize} scheduler task"
          task base_name.to_sym do
            require RAILS_ROOT + '/config/boot'
            require RAILS_ROOT + '/config/environment'
            require path
            task_class = eval class_path.camelize 
            task = task_class.new
            task.run
          end
        end
      end
    end
  end
end


