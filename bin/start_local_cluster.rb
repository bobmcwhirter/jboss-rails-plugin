#!/usr/bin/env ruby

require 'fileutils'

TMP_ROOT = File.dirname( __FILE__ ) + '/../work'

class LocalCluster

  attr_accessor :jboss_home
  def initialize(first_ip='127.0.0.1', number_of_nodes=1, jboss_home=nil)
    @first_ip = first_ip
    @nodes = []
    ip = @first_ip
    1.upto( number_of_nodes ) do |num|
      @nodes << Node.new( self, num, ip )
      ip = ip.succ
    end

    if ( jboss_home.nil? )
      jboss_home = ENV['JBOSS_HOME']
    end
    ( jboss_home.strip! ) unless jboss_home.nil?

    if ( jboss_home.nil? || jboss_home == '' )
      raise "No JBOSS_HOME set"
    end
    @jboss_home = jboss_home
  end

  def start
     @nodes.each do |node|
       node.start
     end
  end

  def stop
    @nodes.each do |node|
      node.stop
    end
  end

  def log(msg)
    puts "[cluster] #{msg}"
  end

  class Node

    def initialize(cluster, node_number, ip)
      @cluster = cluster
      @node_number = node_number
      @ip = ip
      @thread = nil
      @should_stop = false
      log( "created" )
    end

    def start
      log( "starting" )
      @should_stop = false
      @thread = Thread.new( self ) do |node|
        node.run_internal()
      end
    end

    def stop
      return if @thread.nil?
      @should_stop = true
      @thread.join
      @thread = nil
    end

    def run_internal()
      log( "running" )

      temp_dir = TMP_ROOT + "/node-#{@node_number}/tmp"
      FileUtils.mkdir_p( temp_dir ) unless ( File.exist?( temp_dir ) )

      data_dir = TMP_ROOT + "/node-#{@node_number}/data"
      FileUtils.mkdir_p( data_dir ) unless ( File.exist?( data_dir ) )

      cmd = "#{@cluster.jboss_home}/bin/run.sh -c all -b #{@ip} -Djboss.messaging.ServerPeerID=#{@node_number} -Djboss.server.temp.dir=#{temp_dir} -Djboss.server.data.dir=#{data_dir}"
      puts cmd
      open( "|#{cmd}", 'r' ) do |c|
        c.each do |l|
          log( l ) 
          if ( @should_stop )
            break
          end
          Thread.pass
        end
      end
      log( "done run" )
    end

    def log(msg)
      puts "[cluster][node-#{@node_number}] (#{@ip}): #{msg}"
    end
  end

end

first_ip        = ARGV[0]
number_of_nodes = ARGV[1]

puts "first IP: #{first_ip}"
puts "number of nodes: #{number_of_nodes}"

cluster = LocalCluster.new( first_ip, number_of_nodes.to_i )
cluster.start()
cluster.stop()
