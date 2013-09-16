require "json"
require "restfully"
require "fileutils"
require "term/ansicolor"

module XP5K
  class XP

    include Term::ANSIColor

    attr_accessor :jobs, :jobs2submit, :deployments, :todeploy, :connection, :roles, :deployed_nodes
    attr_reader :starttime, :links_deployments

    def initialize(options = {})
      @jobs               = []
      @jobs2submit        = []
      @deployments        = []
      @todeploy           = []
      @roles              = []
      @links_deployments  = {"jobs" => {}, "roles" => {}}
      @deployed_nodes     = {"jobs" => {}, "roles" => {}}
      @retries            = options[:retries] || 3
      @starttime          = Time.now
      @logger             = options[:logger] || Logger.new(STDOUT)

      XP5K::Config.load unless XP5K::Config.loaded?

      @connection = Restfully::Session.new(
        :configuration_file => "~/.restfully/api.grid5000.fr.yml",
        :logger => begin
          tmplogger       = ::Logger.new(STDERR)
          tmplogger.level = ::Logger::WARN
          tmplogger
        end
      )
    end

    def timer
      Time.now - self.starttime
    end

    def define_deployment(deployment_hash)
      deployment_hash[:jobs] ||= []
      deployment_hash[:roles] ||= []
      self.todeploy << deployment_hash
    end

    def deploy()
      # prepare assigned_nodes, goals and retries value
      self.todeploy.each do |x|
        x[:assigned_nodes] = []
        x[:jobs].each do |jobname|
          job = self.job_with_name(jobname)
          self.deployed_nodes["jobs"][jobname] = []
          x[:assigned_nodes] += job["assigned_nodes"]
        end
        x[:roles].each do |rolename|
          role = role_with_name(rolename)
          self.deployed_nodes["roles"][rolename] = []
          x[:assigned_nodes] += role.servers
        end
        # initially all nodes have to be deployed
        x[:nodes] = x[:assigned_nodes]
        # set goal 
        x[:goal] = set_goal(x[:goal], x[:assigned_nodes].length)
        # set retries
        x[:retry] ||= false
        x[:retries] ||= x[:retry]?@retries:1
      end
      internal_deploy(@retries)
      print_deploy_summary
    end
    

    def define_job(job_hash)
      self.jobs2submit << job_hash

      if File.exists?(".xp_cache")
        datas = JSON.parse(File.read(".xp_cache"))
        uid = datas["jobs"].select { |x| x["name"] == job_hash[:name] }.first["uid"]
        unless uid.nil?
          job = @connection.root.sites[job_hash[:site].to_sym].jobs["#{uid}".to_sym]
          if (not job.nil? or job["state"] == "running")
            j = job.reload
            self.jobs << j
            create_roles(j, job_hash) unless job_hash[:roles].nil?
          end
        end
        # reload last deployed nodes
        self.deployed_nodes = datas["deployed_nodes"] 
      end

    end

    def submit
      self.jobs2submit.each do |job2submit|
        job = self.job_with_name(job2submit[:name])
        if job.nil?
          job = @connection.root.sites[job2submit[:site].to_sym].jobs.submit(job2submit)
          #self.jobs << { :uid => job.properties['uid'], :name => job.properties['name'] }
          update_cache
          logger.info "Waiting for the job #{job["name"]} ##{job['uid']} to be running at #{job2submit[:site]}..."
          while job.reload["state"] != "running"
            print(".")
            sleep 3
          end
          self.jobs << job 
          create_roles(job, job2submit) unless job2submit[:roles].nil?
          print(" [#{green("OK")}]\n")
        else
          logger.info "Job #{job["name"]} already submitted ##{job["uid"]}"
        end
      end
      update_cache()
    end

    def create_roles(job, job_definition)
      count_needed_nodes = 0
      job_definition[:roles].each { |role| count_needed_nodes += role.size }
      if job['assigned_nodes'].length < count_needed_nodes
        self.clean
        raise "Job ##{job['uid']} require more nodes for required roles"
      end
      available_nodes = job['assigned_nodes'].sort
      job_definition[:roles].each do |role|
        role.servers = available_nodes[0..(role.size - 1)]
        available_nodes -= role.servers
        role.jobid = job['uid']
        self.roles << role
      end
    end

    def job_with_name(name)
      self.jobs.select { |x| x["name"] == name }.first
    end

    def role_with_name(name)
      self.roles.select { |x| x.name == name}.first
    end

    def get_deployed_nodes(job_or_role_name)
      if self.deployed_nodes["jobs"].has_key?(job_or_role_name)
        return self.deployed_nodes["jobs"][job_or_role_name]
      end
      if self.deployed_nodes["roles"].has_key?(job_or_role_name)
        return self.deployed_nodes["roles"][job_or_role_name]
      end
    end

    def status
      self.jobs.each do |job|
        logger.info "Job #{job["name"]} ##{job["uid"]} status : #{job["state"]}"
      end
    end

    def clean
      self.jobs.each do |job|
        if job.reload["state"] == "running"
          job.delete
          logger.info "Job ##{job["uid"]} deleted !"
        end
      end
      FileUtils.rm(".xp_cache")
    end

    private

    def logger
      @logger
    end
    
    def update_links_deployments (duid, todeploy)
      unless todeploy[:jobs].nil?
        todeploy[:jobs].each do |job|
          @links_deployments["jobs"][job] ||= []  
          @links_deployments["jobs"][job] << duid  
        end
      end

      unless todeploy[:roles].nil?
        todeploy[:roles].each do |role|
          @links_deployments["roles"][role] ||= []  
          @links_deployments["roles"][role] << duid  
        end
      end
    end

    def update_deployed_nodes
      self.links_deployments["jobs"].each do |jobname,v|
        job = job_with_name(jobname)
        deployed_nodes["jobs"][jobname]=[]
        v.each do |duid| 
          deployment = self.deployments.select{ |d| d["uid"] == duid}.first
          deployed_nodes["jobs"][jobname] += intersect_nodes_job(job, deployment)
        end
      end

      self.links_deployments["roles"].each do |rolename,v|
        role = role_with_name(rolename)
        deployed_nodes["roles"][rolename]=[]
        v.each do |duid| 
          deployment = self.deployments.select{ |d| d["uid"] == duid}.first
          deployed_nodes["roles"][rolename] += intersect_nodes_role(role, deployment)
        end
      end

    end
    
    def intersect_nodes_job (job, deployment)
      nodes_deployed = deployment["result"].select{ |k,v| v["state"]=='OK'}.keys
      return job["assigned_nodes"] & nodes_deployed
    end

    def intersect_nodes_role (role, deployment)
      nodes_deployed = deployment["result"].select{ |k,v| v["state"]=='OK'}.keys
      return role.servers & nodes_deployed
    end
    
    def update_cache
      cache = { 
        :jobs               => self.jobs.collect { |x| x.properties },
        :roles              => self.roles.map{ |x| { :name => x.name, :size => x.size, :servers => x.servers }},
        :deployed_nodes     => self.deployed_nodes,
        :links_deployments  => self.links_deployments
      }
      open(".xp_cache", "w") do |f|
        f.puts cache.to_json
      end
    end

    def internal_deploy(n)

      if (n<=0)
        return
      end

      # Fill with nodes to deployed
      self.todeploy.each do |x|
        x[:nodes] = x[:assigned_nodes] 
        x[:jobs].each do |jobname|
          x[:nodes] = x[:nodes] - self.deployed_nodes["jobs"][jobname]
        end
        x[:roles].each do |rolename|
          x[:nodes] = x[:nodes] - self.deployed_nodes["roles"][rolename]
        end
      end

      # Clean todeploy
      self.todeploy.delete_if{ |x|
        x[:nodes].empty? ||
        (x[:goal] >= 0) && ( x[:nodes].length < ((1-x[:goal])*(x[:assigned_nodes].length ))) ||
        x[:retries] <= 0
      }

      if self.todeploy.empty? 
        return
      end

      if (n<@retries)
        logger.info "Redeployment of undeployed nodes"
      end

      # Launch deployments
      self.todeploy.each do |y|
        x = y.clone  
        site = x[:site]
        x.delete(:site)
        x.delete(:roles)
        x.delete(:jobs)
        x.delete(:assigned_nodes)
        x.delete(:goal)
        x.delete(:retry)
        x.delete(:retries)

        deployment = @connection.root.sites[site.to_sym].deployments.submit(x)
        self.deployments << deployment
        # Update links_deployments
        update_links_deployments(deployment["uid"], y)
        y[:retries] = y[:retries] - 1
      end

      logger.info "Waiting for all the deployments to be terminated..."
      finished = self.deployments.reduce(true){ |acc, d| acc && d["status"]!='processing'}
      while (!finished)
        sleep 10
        print "."
        self.deployments.each do |deployment|
          deployment.reload
        end
        finished = self.deployments.reduce(true){ |acc, d| acc && d["status"]!='processing'}
      end
      print(" [#{green("OK")}]\n")

      # Update deployed nodes
      update_deployed_nodes()
      update_cache()

      internal_deploy(n - 1)

    end

    def set_goal(goal, total)
      if goal.nil?
        return -1.0
      end

      if goal.to_s.include? "%"
          return goal.to_f/100
      elsif goal.to_f < 1
        return goal.to_f
      elsif goal.to_f == 1.0
        return goal.to_f/total
      else 
        return goal.to_f/total
      end
    end

    def print_deploy_summary
      puts "Summary of the deployment"
      puts "-" * 60 
      printf "%+20s", "Name"
      printf "%+20s", "Deployed"
      printf "%+20s", "Undeployed"
      puts "\n"
      puts "-" * 60 

      self.deployed_nodes["jobs"].each do |jobname, deployed_nodes|
        puts "\n"
        printf "%+20s",jobname 
        printf "%20d", deployed_nodes.length
        printf "%20d", job_with_name(jobname)["assigned_nodes"].length - deployed_nodes.length
        puts "\n"
      end

      self.deployed_nodes["roles"].each do |rolename, deployed_nodes|
        printf "%+20s",rolename 
        printf "%20d", deployed_nodes.length
        printf "%20d", role_with_name(rolename).servers.length - deployed_nodes.length
        puts "\n"
      end
    end
  end
end
