# -*- encoding: utf-8 -*-

module Zeus
  class Server
    class ProcessTreeRenderer
      LINE_T = "\x1b[33m├── "
      LINE_L = "\x1b[33m└── "
      LINE_I = "\x1b[33m│   "
      LINE_X = "\x1b[33m    "

      GREEN = "\x1b[32m"
      RED   = "\x1b[31m"

      CLEAR_LINES_UPWARD = ->(n) { "\x1b[1A\x1b[K" * n }

      def initialize(tree)
        @stdout = $stdout
        @stdin = $stdin
        @r, @w = IO.pipe
        @r2, @w2 = IO.pipe
        $stdin = @r2
        $stdout = @w
        $stderr = @w
        @tree = tree
        @stdin_text = ""
      end

      def render(node=@tree, my_indentation="", child_indentation="")
        color = node.pid ? GREEN : RED
        str = "#{my_indentation}#{color}#{node.name}\x1b[0m\n"

        indent = ->(x){"#{child_indentation}#{x}"}

        node.stages.each do |child|
          if child == node.stages.last
            str << render(child, indent.(LINE_L), indent.(LINE_X))
          else
            str << render(child, indent.(LINE_T), indent.(LINE_I))
          end
        end

        str
      end

      def get_stdout
        str = ""
        loop do
          begin
            str << @r.read_nonblock(1024)
          rescue Errno::EAGAIN
            return str
          end
        end
      end

      def get_stdin
        text = @r2.read_nonblock(1024)
        @stdin_text << text
        text
      rescue Errno::EAGAIN
      end

      def run!
        @tid = Thread.new {
          draw
          loop do
            if IO.select([@stdin], [], [], 0.3)
              # @stdout.print(get_stdin)
            end
            draw
          end
        }
      end

      def stop
        @tid.kill
      end

      def draw
        last = @last_render
        @last_render = render

        stdout = get_stdout

        last_length = last ? last.lines.count : -1

        str = CLEAR_LINES_UPWARD.(last_length+1) + stdout +
          "\x1b[32m--\x1b[33m[\x1b[32mZEUS STATUS\x1b[33m]\x1b[32m--------------------\x1b[0m\n" +
          render

        @stdout.syswrite str
      end

    end
  end
end
