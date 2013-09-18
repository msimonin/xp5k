require 'spec_helper'
require 'rspec'


describe '#deploy_nodes' do
  before(:each) do
    @deployment_result1  = { 
      "uid"     => "testdeployment1",
      "status"  => "terminated",
      "result"  => {
        "node1" => {
          "state" => "OK"
        },
        "node2" => {
          "state"=>"OK"
        },
        "node3" => {
          "state"=> "OK",
        },
        "node4" => {
          "state"=> "KO",
        },
        "node5" => {
          "state"=> "KO",
        }
      }
    }

    @deployment_result20  = { 
      "uid"     => "testdeployment20",
      "status"  => "terminated",
      "result"  => {
        "node4" => {
          "state"=> "OK"
        },
        "node5" => {
          "state"=> "OK",
        }
      }
    }

    # alternative result
    @deployment_result02  = { 
      "uid"     => "testdeployment02",
      "status"  => "terminated",
      "result"  => {
        "node4" => {
          "state"=> "KO"
        },
        "node5" => {
          "state"=> "KO",
        }
      }
    }


  end

  context 'Without redeploying' do
    it 'should filled deployed nodes with 2 nodes (on 2)' do
      @deployment_result1.stub(:reload).and_return(@deployment_result1)
      deployments = double("connection.root.sites[:test].deployments")
      deployments.stub(:submit).and_return(@deployment_result1)
      site_test = double("connection.root.sites[:test]")
      site_test.stub(:deployments).and_return(deployments)
      root = double("connection.root")
      root.stub(:sites).and_return({:test => site_test})
      connection = double("connection")
      connection.stub(:root).and_return(root)
      Restfully::Session.stub(:new).and_return(connection)
      @myxp = XP5K::XP.new()

      # input (output of define_deployments)
      deploy1= {
         :site          => 'test',
         :environnement => 'testenv',
         :jobs          => %w(testjob), #is filled by define_deployment 
         :roles         => %w()         #is filled by define_deployment

      }
      @myxp.define_deployment(deploy1)

      # input (output of define_jobs)
      @myxp.jobs << {
        "assigned_nodes" => ["node1", "node2"],
        "uid"            => "testjob",
        "name"           => "testjob",
        "state"          => "running"
      }
      @myxp.stub(:update_cache)
      @myxp.deploy
      deployed_nodes = @myxp.deployed_nodes["jobs"]["testjob"]
      expect(deployed_nodes.length).to eql(2)
      expect(deployed_nodes).to include("node1", "node2")

      expect(@myxp.job_with_name("testjob")["assigned_nodes"].length).to eql(2)
      expect(@myxp.job_with_name("testjob")["assigned_nodes"]).to include("node1", "node2")
    end

    it 'should filled deployed nodes with 0 nodes (on 2)' do
      @deployment_result02.stub(:reload).and_return(@deployment_result02)
      deployments = double("connection.root.sites[:test].deployments")
      deployments.stub(:submit).and_return(@deployment_result02)
      site_test = double("connection.root.sites[:test]")
      site_test.stub(:deployments).and_return(deployments)
      root = double("connection.root")
      root.stub(:sites).and_return({:test => site_test})
      connection = double("connection")
      connection.stub(:root).and_return(root)
      Restfully::Session.stub(:new).and_return(connection)
      @myxp = XP5K::XP.new()

      # input (output of define_deployments)
      deploy1= {
         :site          => 'test',
         :environnement => 'testenv',
         :jobs          => %w(testjob), #is filled by define_deployment 
         :roles         => %w()         #is filled by define_deployment

      }
      @myxp.define_deployment(deploy1)

      # input (output of define_jobs)
      @myxp.jobs << {
        "assigned_nodes" => ["node4", "node5"],
        "uid"            => "testjob",
        "name"           => "testjob",
        "state"          => "running"
      }
      @myxp.stub(:update_cache)
      @myxp.deploy
      deployed_nodes = @myxp.deployed_nodes["jobs"]["testjob"]
      expect(deployed_nodes.length).to eql(0)

      expect(@myxp.job_with_name("testjob")["assigned_nodes"].length).to eql(2)
      expect(@myxp.job_with_name("testjob")["assigned_nodes"]).to include("node4", "node5")
    end

    it 'should filled deployed nodes with  nodes 3 (on 5)' do
      @deployment_result1.stub(:reload).and_return(@deployment_result1)
      deployments = double("connection.root.sites[:test].deployments")
      deployments.stub(:submit).and_return(@deployment_result1)
      site_test = double("connection.root.sites[:test]")
      site_test.stub(:deployments).and_return(deployments)
      root = double("connection.root")
      root.stub(:sites).and_return({:test => site_test})
      connection = double("connection")
      connection.stub(:root).and_return(root)
      Restfully::Session.stub(:new).and_return(connection)
      @myxp = XP5K::XP.new()

      # input (output of define_deployments)
      deploy1= {
         :site          => 'test',
         :environnement => 'testenv',
         :jobs          => %w(testjob), 
         :roles         => %w()         

      }
      @myxp.define_deployment(deploy1)

      # input (output of define_jobs)
      @myxp.jobs << {
        "assigned_nodes" => ["node1", "node2", "node3", "node4", "node5"],
        "uid"            => "testjob",
        "name"           => "testjob",
        "state"          => "running"
      }
      @myxp.stub(:update_cache)
      @myxp.deploy
      deployed_nodes = @myxp.deployed_nodes["jobs"]["testjob"]
      expect(deployed_nodes.length).to eql(3)
      expect(deployed_nodes).to include("node1", "node2", "node3") 

      expect(@myxp.job_with_name("testjob")["assigned_nodes"].length).to eql(5)
      expect(@myxp.job_with_name("testjob")["assigned_nodes"]).to include("node1", "node2", "node3", "node4", "node5")
    end

  end

  context 'With redeploying and different goal and retries' do
    before :each do
      @deployment_result1.stub(:reload).and_return(@deployment_result1)
      @deployment_result20.stub(:reload).and_return(@deployment_result20)
      deployments = double("connection.root.sites[:test].deployments")
      deployments.stub(:submit).and_return(@deployment_result1, @deployment_result20)
      site_test = double("connection.root.sites[:test]")
      site_test.stub(:deployments).and_return(deployments)
      root = double("connection.root")
      root.stub(:sites).and_return({:test => site_test})
      connection = double("connection")
      connection.stub(:root).and_return(root)
      Restfully::Session.stub(:new).and_return(connection)
      @myxp = XP5K::XP.new()
      @myxp.stub(:update_cache)

      # input (output of define_deployments)
      @deploy1={
         :site          => 'test',
         :environnement => 'testenv',
         :jobs          => %w(testjob), 
         :roles         => %w(),       
         :retry         => true,
      }
      # input (output of define_jobs)
      @myxp.jobs << {
        "assigned_nodes" => ["node1", "node2", "node3", "node4", "node5"],
        "uid"            => "testjob",
        "name"           => "testjob",
        "state"          => "running"
      }
    end

    it 'should filled the job with only the 3 nodes deployed (on 3)' do
      @myxp.define_deployment(@deploy1)
      @myxp.deploy
      deployed_nodes = @myxp.deployed_nodes["jobs"]["testjob"]
      puts deployed_nodes.inspect
      expect(deployed_nodes.length).to eql(5)
      expect(deployed_nodes).to include("node1", "node2", "node3", "node4", "node5") 

      expect(@myxp.job_with_name("testjob")["assigned_nodes"].length).to eql(5)
      expect(@myxp.job_with_name("testjob")["assigned_nodes"]).to include("node1", "node2", "node3", "node4", "node5")
    end

    it 'should filled the job with only the 3 nodes deployed (retry enable + goal to 50%)' do
      @deploy1[:retry] = true
      @deploy1[:goal] = "50%"

      @myxp.define_deployment(@deploy1)
      @myxp.deploy
      deployed_nodes = @myxp.deployed_nodes["jobs"]["testjob"]
      puts deployed_nodes.inspect
      expect(deployed_nodes.length).to eql(3)
      expect(deployed_nodes).to include("node1", "node2", "node3") 

      expect(@myxp.job_with_name("testjob")["assigned_nodes"].length).to eql(5)
      expect(@myxp.job_with_name("testjob")["assigned_nodes"]).to include("node1", "node2", "node3", "node4", "node5")
    end


    it 'should filled the job with only the 5 nodes deployed (retry enable + goal to 75%)' do
      @deploy1[:retry] = true
      @deploy1[:goal] = "75%"

      @myxp.define_deployment(@deploy1)
      @myxp.deploy
      deployed_nodes = @myxp.deployed_nodes["jobs"]["testjob"]
      puts deployed_nodes.inspect
      expect(deployed_nodes.length).to eql(5)
      expect(deployed_nodes).to include("node1", "node2", "node3", "node4", "node5") 

      expect(@myxp.job_with_name("testjob")["assigned_nodes"].length).to eql(5)
      expect(@myxp.job_with_name("testjob")["assigned_nodes"]).to include("node1", "node2", "node3", "node4", "node5")
    end

    it 'should filled the job with only the 5 nodes deployed (retry enable + goal to 1)' do
      @deploy1[:retry] = true
      @deploy1[:goal] = "1"

      @myxp.define_deployment(@deploy1)
      @myxp.deploy
      deployed_nodes = @myxp.deployed_nodes["jobs"]["testjob"]
      puts deployed_nodes.inspect
      expect(deployed_nodes.length).to eql(3)
      expect(deployed_nodes).to include("node1", "node2", "node3") 

      expect(@myxp.job_with_name("testjob")["assigned_nodes"].length).to eql(5)
      expect(@myxp.job_with_name("testjob")["assigned_nodes"]).to include("node1", "node2", "node3", "node4", "node5")
    end
  end

  context '3 rounds : 0 node (on 2) deployed' do
    it 'job deployed node should be empty' do
      deployment_result02a = @deployment_result02.clone
      deployment_result02a["uid"] = "deployment_result02a"
      deployment_result02b = @deployment_result02.clone
      deployment_result02b["uid"] = "deployment_result02b"
      deployment_result02c = @deployment_result02.clone
      deployment_result02c["uid"] = "deployment_result02c"

      deployment_result02a.stub(:reload).and_return(deployment_result02a)
      deployment_result02b.stub(:reload).and_return(deployment_result02b)
      deployment_result02c.stub(:reload).and_return(deployment_result02c)

      deployments = double("connection.root.sites[:test].deployments")
      deployments.stub(:submit).and_return(deployment_result02a, deployment_result02b, deployment_result02c)

      site_test = double("connection.root.sites[:test]")
      site_test.stub(:deployments).and_return(deployments)
      root = double("connection.root")
      root.stub(:sites).and_return({:test => site_test})
      connection = double("connection")
      connection.stub(:root).and_return(root)
      Restfully::Session.stub(:new).and_return(connection)
      @myxp = XP5K::XP.new()
      # input (output of define_deployments)
      deploy1={
         :site          => 'test',
         :environnement => 'testenv',
         :jobs          => %w(testjob), 
         :roles         => %w(),
         :retry         => true,
         :retries       => 3
      }
      @myxp.define_deployment(deploy1)

      # input (output of define_jobs)
      @myxp.jobs << {
        "assigned_nodes" => ["node4", "node5"],
        "uid"            => "testjob",
        "name"           => "testjob",
        "state"          => "running"
      }

      @myxp.stub(:update_cache)
      @myxp.deploy
      expect(@myxp.links_deployments["jobs"]).to eql({"testjob" => ["deployment_result02a", "deployment_result02b", "deployment_result02c"]})
      deployed_nodes = @myxp.deployed_nodes["jobs"]["testjob"]
      expect(deployed_nodes.length).to eql(0)

      expect(@myxp.job_with_name("testjob")["assigned_nodes"].length).to eql(2)
      expect(@myxp.job_with_name("testjob")["assigned_nodes"]).to include("node4", "node5")
    end
  end

  context '1 round : with roles (size 1 and size 2) and all nodes deployed' do
    it 'should fill role.deployed nodes with size 1 and size 2 respectively' do
      @deployment_result1.stub(:reload).and_return(@deployment_result1)
      deployments = double("connection.root.sites[:test].deployments")
      deployments.stub(:submit).and_return(@deployment_result1)
      site_test = double("connection.root.sites[:test]")
      site_test.stub(:deployments).and_return(deployments)
      root = double("connection.root")
      root.stub(:sites).and_return({:test => site_test})
      connection = double("connection")
      connection.stub(:root).and_return(root)
      Restfully::Session.stub(:new).and_return(connection)
      @myxp = XP5K::XP.new()

      deploy1={
         :site          => 'test',
         :environnement => 'testenv',
         :jobs          => %w(),            
         :roles         => %w(role1 role2), 
         :retry         => true,
         :goal          => "100%"
      }
      @myxp.define_deployment(deploy1)

      # input (output of define_jobs with 2 roles)
      @myxp.jobs << {
        "assigned_nodes" => ["node1", "node2", "node3"],
        "uid"            => "testjob",
        "name"           => "testjob",
        "state"          => "running"
      }
      role1 = XP5K::Role.new({ :name => 'role1', :size => 1})
      role1.servers = ["node1"]
      role2 = XP5K::Role.new({ :name => 'role2', :size => 2})
      role2.servers = ["node2", "node3"]
      @myxp.roles << role1 << role2
      # end of define_job input

      @myxp.stub(:update_cache)
      @myxp.deploy

      expect(@myxp.links_deployments["roles"]).to eql({"role1" => ["testdeployment1"], "role2" => ["testdeployment1"]})
      deployed1 = @myxp.deployed_nodes["roles"]["role1"]
      expect(deployed1).to eql(["node1"])
      deployed2 = @myxp.deployed_nodes["roles"]["role2"]
      expect(deployed2).to eql(["node2", "node3"])

      expect(@myxp.role_with_name("role1").servers.length).to eql(1)
      expect(@myxp.role_with_name("role1").servers).to include("node1")
      expect(@myxp.role_with_name("role2").servers.length).to eql(2)
      expect(@myxp.role_with_name("role2").servers).to include("node2", "node3")

    end
  end

  context '2 rounds : with roles (size 1 and size 2) and 2 of 3 nodes deployed' do
    it 'should fill role.deployed nodes with size 1 and size 1 respectively' do
      @deployment_result1.stub(:reload).and_return(@deployment_result1)
      @deployment_result20.stub(:reload).and_return(@deployment_result20)
      deployments = double("connection.root.sites[:test].deployments")
      deployments.stub(:submit).and_return(@deployment_result1, @deployment_result20)
      site_test = double("connection.root.sites[:test]")
      site_test.stub(:deployments).and_return(deployments)
      root = double("connection.root")
      root.stub(:sites).and_return({:test => site_test})
      connection = double("connection")
      connection.stub(:root).and_return(root)
      Restfully::Session.stub(:new).and_return(connection)
      @myxp = XP5K::XP.new()

      # input (output of define_deployments)
      deploy1={
         :site          => 'test',
         :environnement => 'testenv',
         :jobs          => %w(), #is filled by define_deployment 
         :roles         => %w(role1 role2),             #is filled by define_deployment
         :retry         => true,
         :goal          => "100%"
      }
      @myxp.define_deployment(deploy1)

      # input (output of define_jobs with 2 roles)
      @myxp.jobs << {
        "assigned_nodes" => ["node2", "node3", "node4"],
        "uid"            => "testjob",
        "name"           => "testjob",
        "state"          => "running"
      }
      role1 = XP5K::Role.new({ :name => 'role1', :size => 1})
      role1.servers = ["node2"]
      role2 = XP5K::Role.new({ :name => 'role2', :size => 2})
      role2.servers = ["node3", "node4"]
      @myxp.roles << role1 << role2
      # end of define_job input

      @myxp.stub(:update_cache)

      @myxp.deploy

      expect(@myxp.links_deployments["roles"]).to eql({"role1" => ["testdeployment1", "testdeployment20"], "role2" => ["testdeployment1","testdeployment20"]})
      deployed1 = @myxp.deployed_nodes["roles"]["role1"]
      expect(deployed1).to eql(["node2"])
      deployed2 = @myxp.deployed_nodes["roles"]["role2"]
      expect(deployed2).to eql(["node3","node4"])

      expect(@myxp.role_with_name("role1").servers.length).to eql(1)
      expect(@myxp.role_with_name("role1").servers).to include("node2")
      expect(@myxp.role_with_name("role2").servers.length).to eql(2)
      expect(@myxp.role_with_name("role2").servers).to include("node3", "node4")

    end
  end

  context '3 rounds : with roles (size 1 and size 2) and 2 of 3 nodes deployed' do
    it 'should fill role.deployed nodes with size 1 and size 1 respectively' do
      deployment_result1 = @deployment_result1.clone
      deployment_result1["uid"] = "deployment_result1"
      deployment_result2 = @deployment_result02.clone
      deployment_result2["uid"] = "deployment_result2"
      deployment_result3 = @deployment_result02.clone
      deployment_result3["uid"] = "deployment_result3"
      deployments = double("connection.root.sites[:test].deployments")
      deployments.stub(:submit).and_return(deployment_result1, deployment_result2, deployment_result3)

      deployment_result1.stub(:reload).and_return(deployment_result1)
      deployment_result2.stub(:reload).and_return(deployment_result2)
      deployment_result3.stub(:reload).and_return(deployment_result3)

      site_test = double("connection.root.sites[:test]")
      site_test.stub(:deployments).and_return(deployments)
      root = double("connection.root")
      root.stub(:sites).and_return({:test => site_test})
      connection = double("connection")
      connection.stub(:root).and_return(root)
      Restfully::Session.stub(:new).and_return(connection)
      @myxp = XP5K::XP.new()

      # input (output of define_deployments)
      deploy1={
         :site          => 'test',
         :environnement => 'testenv',
         :jobs          => %w(), #is filled by define_deployment 
         :roles         => %w(role1 role2),             #is filled by define_deployment
         :retry         => true,
         :goal          => "100%"
      }
      @myxp.define_deployment(deploy1)

      # input (output of define_jobs with 2 roles)
      @myxp.jobs << {
        "assigned_nodes" => ["node2", "node3", "node4"],
        "uid"            => "testjob",
        "name"           => "testjob",
        "state"          => "running"
      }
      role1 = XP5K::Role.new({ :name => 'role1', :size => 1})
      role1.servers = ["node2"]
      role2 = XP5K::Role.new({ :name => 'role2', :size => 2})
      role2.servers = ["node3", "node4"]
      @myxp.roles << role1 << role2
      # end of define_job input

      @myxp.stub(:update_cache)

      @myxp.deploy

      expect(@myxp.links_deployments["roles"]).to eql({"role1" => ["deployment_result1", "deployment_result2", "deployment_result3"], "role2" => ["deployment_result1","deployment_result2", "deployment_result3"]})
      deployed1 = @myxp.deployed_nodes["roles"]["role1"]
      expect(deployed1).to eql(["node2"])
      deployed2 = @myxp.deployed_nodes["roles"]["role2"]
      expect(deployed2).to eql(["node3"])

      expect(@myxp.role_with_name("role1").servers.length).to eql(1)
      expect(@myxp.role_with_name("role1").servers).to include("node2")
      expect(@myxp.role_with_name("role2").servers.length).to eql(2)
      expect(@myxp.role_with_name("role2").servers).to include("node3", "node4")
    end
  end

end
