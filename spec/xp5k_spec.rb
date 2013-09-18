require 'xp5k'

describe '#set_goal' do
  before(:each) do
    site_test = double("site_test")
    root = double("connection.root")
    root.stub(:sites).and_return({:test => site_test})
    connection = double("connection")
    connection.stub(:root).and_return(root)
    Restfully::Session.stub(:new).and_return(connection)
    @myxp = XP5K::XP.new()
  end

  context 'with nil goal' do
    it 'shoud return a negative value' do
      goal = @myxp.send(:set_goal, nil, 23)
      expect(goal).to be < 0
    end
  end

  context 'with % goal' do
    it 'should return the corresponding ratio' do
      goal = @myxp.send(:set_goal, "10%", 23)
      expect(goal).to eql(0.1)
    end

    it 'should return the corresponding ratio' do
      goal = @myxp.send(:set_goal, "10 %", 23)
      expect(goal).to eql(0.1)
    end
  end

  context 'with a ratio' do
    it 'should return the ratio' do
      goal = @myxp.send(:set_goal, 0.1, 23) 
      expect(goal).to eql(0.1)
    end

    it 'should return the ratio' do
      goal = @myxp.send(:set_goal, "0.1", 23) 
      expect(goal).to eql(0.1)
    end
  end

  context 'with an absolute number of nodes' do
    it 'should return the ratio' do
      goal = @myxp.send(:set_goal, 10, 23)
      expect(goal).to eql(10.0/23.0)
    end

    it 'should return the ratio' do
      goal = @myxp.send(:set_goal, "10", 23)
      expect(goal).to eql(10.0/23.0)
    end

    it 'sould return the ratio' do
      goal = @myxp.send(:set_goal, "1", 23)
      expect(goal).to eql(1.0/23.0)
    end
  end


end

describe '#create_roles' do
  before(:each) do
    site_test = double("site_test")
    root = double("connection.root")
    root.stub(:sites).and_return({:test => site_test})
    connection = double("connection")
    connection.stub(:root).and_return(root)
    Restfully::Session.stub(:new).and_return(connection)
    @myxp = XP5K::XP.new()
  end

  context 'with enough nodes' do
    it 'should filled roles in alphabetical order' do
        job             = {"name" => "test", "uid" => "1", "assigned_nodes" => ["node1", "node2", "node3"]}
        job_definition  = {
          :roles      => [
            XP5K::Role.new({ :name => 'role1', :size => 1 }),
            XP5K::Role.new({ :name => 'role2', :size => 2})
          ]
        }
        @myxp.create_roles(job, job_definition)
        @myxp.roles.should have(2).role
        @myxp.roles.select{|x| x.name == 'role1'}.first.servers.should eql(["node1"])
        @myxp.roles.select{|x| x.name == 'role2'}.first.servers.should eql(["node2","node3"])
    end
  end
=begin
  context 'with not enough nodes' do
      it 'should raise an error' do
          job             = {"name" => "test", "uid" => "1", "assigned_nodes" => ["node1", "node2", "node3"]}
          job_definition  = {
            :roles      => [
              XP5K::Role.new({ :name => 'role1', :size => 2 }),
              XP5K::Role.new({ :name => 'role2', :size => 2})
            ]
          }
          @myxp.create_roles(job, job_definition).should raise_error()
      end
    end
=end
end

describe '#intersect_nodes_job' do
  before(:each) do
    site_test = double("site_test")
    root = double("connection.root")
    root.stub(:sites).and_return({:test => site_test})
    connection = double("connection")
    connection.stub(:root).and_return(root)
    Restfully::Session.stub(:new).and_return(connection)
    @myxp = XP5K::XP.new()
    @deployment  = { 
      "result" => {
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
  end

  context 'when all the 3 (on 3) nodes are deployed' do
    it 'should return the 3 deployed nodes' do
      job         = {"name" => "test", "uid" => "1", "assigned_nodes" => ["node1", "node2", "node3"]}
      deployed_nodes = @myxp.send(:intersect_nodes_job, job, @deployment)
      expect(deployed_nodes.length).to eq(3)
      expect(deployed_nodes).to include("node1", "node2", "node3")
    end
  end

  context 'when only 3 nodes (on 5) are deployed' do
    it 'should return the 3 nodes' do
      job         = {"name" => "test", "uid" => "1", "assigned_nodes" => ["node1", "node2", "node3", "node4", "node5"]}
      deployed_nodes = @myxp.send(:intersect_nodes_job, job, @deployment)
      expect(deployed_nodes.length).to eq(3)
      expect(deployed_nodes).to include("node1", "node2", "node3")

    end
  end

  context 'when no nodes are deployed' do
    it 'should return the 0 deployed nodes' do
      job         = {"name" => "test", "uid" => "1", "assigned_nodes" => ["node4'", "node5"]}
      deployed_nodes = @myxp.send(:intersect_nodes_job, job, @deployment)
      expect(deployed_nodes.length).to eq(0)
    end
  end
end

