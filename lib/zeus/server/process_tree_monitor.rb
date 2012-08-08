module Zeus
  class Server
    class ProcessTreeMonitor
      STATUS_TYPE = "S"
      FEATURE_TYPE = "F"

      def datasource          ; @sock ; end
      def on_datasource_event ; handle_messages ; end
      def close_child_socket  ; @__CHILD__sock.close ; end
      def close_parent_socket ; @sock.close ; end

      def initialize(file_monitor, tree)
        @tree = tree
        @file_monitor = file_monitor

        @sock, @__CHILD__sock = open_socketpair
      end

      def kill_nodes_with_feature(file)
        @tree.kill_nodes_with_feature(file)
      end

      module ChildProcessApi
        def __CHILD__status(pid, status, name)
          @__CHILD__sock.send("#{STATUS_TYPE}#{pid}:#{status.to_s}:#{name.to_s}", 0)
        rescue Errno::ENOBUFS
          sleep 0.2
          retry
        end

        def __CHILD__stage_has_feature(name, feature)
          @__CHILD__sock.send("#{FEATURE_TYPE}#{name.to_s}:#{feature}", 0)
        rescue Errno::ENOBUFS
          sleep 0.2
          retry
        end
      end ; include ChildProcessApi


      private

      def handle_messages
        50.times { handle_message }
      rescue Errno::EAGAIN
      end

      def handle_message
        data = @sock.recv_nonblock(4096)
        case data[0]
        when FEATURE_TYPE
          handle_feature_message(data[1..-1])
        when STATUS_TYPE
          handle_status_message(data[1..-1])
        end
      end

      def open_socketpair
        Socket.pair(:UNIX, :DGRAM)
      end

      def handle_status_message(data)
        data =~ /(\d+):(.+?):(.+)/
          pid, status, name = $1.to_i, $2, $3
        puts [pid, status, name].inspect
        @tree.update_status(pid, status, name.to_sym)
      end

      def handle_feature_message(data)
        data =~ /(.+?):(.*)/
          name, file = $1, $2
        @tree.stage_has_feature(name.to_sym, file)
        @file_monitor.watch(file)
      end


    end
  end
end
