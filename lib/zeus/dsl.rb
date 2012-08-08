module Zeus
  module DSL

    class Evaluator
      def stage(name, &b)
        stage = DSL::Stage.new(name)
        stage.instance_eval(&b)
      end
    end

    class Node
      attr_accessor :pid, :features
      attr_reader :name, :stages

      def initialize
        @stages = []
        @features = {}
      end

      def add_feature(feature)
        features[feature] = true
      end

      def has_feature?(feature)
        features[feature]
      end

      def kill
        Process.kill("INT", @pid) if @pid
      end

      def update_status(pid, status, name)
        if name == @name
          puts [status, pid, name, :i].inspect
          if status == :killing
            @pid = nil
          else
            @pid = pid
          end
          @status = status
        else
          stages.each do |child|
            child.update_status(pid, status, name)
          end
        end
      end

      # TODO: Cache stages by name in the top object so
      # we don't have to recurse a bajillion times
      def stage_has_feature(name, feature)
        if name == @name
          add_feature(feature)
        else
          stages.each do |child|
            child.stage_has_feature(name, feature)
          end
        end
      end

      def kill_nodes_with_feature(feature, parent_killed=false)
        should_kill = has_feature?(feature) || parent_killed
        puts "KILLING NODES WITH #{feature} (#{should_kill} in #{name})"
        stages.each do |child|
          child.kill_nodes_with_feature(feature, should_kill)
        end
        kill() if should_kill
      end

    end

    class Acceptor < Node

      attr_reader :aliases, :description, :action
      def initialize(name, aliases, description, &b)
        super()
        @name = name
        @description = description
        @aliases = aliases
        @action = b
      end

      # ^ configuration
      # V later use

      def commands
        [name, *aliases].map(&:to_s)
      end

      def acceptors
        self
      end

      def to_domain_object(server)
        Zeus::Server::Acceptor.new(server).tap do |stage|
          stage.name = @name
          stage.aliases = @aliases
          stage.action = @action
          stage.description = @description
        end
      end

    end

    class Stage < Node

      attr_reader :actions
      def initialize(name)
        super()
        @name = name
        @stages, @actions = [], []
      end

      def action(&b)
        @actions << b
        self
      end

      def desc(desc)
        @desc = desc
      end

      def stage(name, &b)
        @stages << DSL::Stage.new(name).tap { |s| s.instance_eval(&b) }
        self
      end

      def command(name, *aliases, &b)
        @stages << DSL::Acceptor.new(name, aliases, @desc, &b)
        @desc = nil
        self
      end

      # ^ configuration
      # V later use

      def acceptors
        stages.map(&:acceptors).flatten
      end

      def to_domain_object(server)
        Zeus::Server::Stage.new(server).tap do |stage|
          stage.name = @name
          stage.stages = @stages.map { |stage| stage.to_domain_object(server) }
          stage.actions = @actions
        end
      end

    end

  end
end
