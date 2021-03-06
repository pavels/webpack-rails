require_relative 'file_mutex'

module WebpackDevServer
  class WebpackRunner
    class << self
      def socket_path
        File.expand_path(config.dev_server.socket_path)
      end

      def config
        ::Rails.configuration.webpack
      end

      def webpack_cmd
        config.dev_server.binary
      end

      def webpack_opts
         "--host localhost --port #{socket_path} #{config.dev_server.server_options} --config #{config.config_file}"
      end

      def mutex
        @mutex ||= FileMutex.new('webpack-server')
      end

      def run
        @run_count ||= 0
        return if @run_count > 0 && mutex.get

        if mutex.acquire
          log "Lock acquired on PID file #{mutex.lock_file_path}"

          check_existing_pid

          log 'Starting webpack-dev-server...'
          log "#{webpack_cmd} #{webpack_opts}"
          delete_socket

          pid = Process.spawn(
            "#{webpack_cmd} #{webpack_opts}",
            pgroup: true,
            out: $stdout,
            err: $stderr
          )
          mutex.set( pid )
          log "Webpack started with PID #{pid}"

        else
          log "PID file #{mutex.lock_file_path} is already locked."
          log 'Webpack should be running. Otherwise try deleting the PID file and restarting.'
        end

        @run_count += 1
      end

      def shutdown( pid = nil )
        mutex_pid = mutex.get
        pid ||= mutex_pid

        return unless pid && mutex.acquire

        begin
          log "Sending SIGINT to pgroup #{pid}"
          Process.kill '-INT', pid
        rescue Errno::ESRCH, Errno::EPERM
          log "pgroup #{pid} does not exist"
        end

        log "Waiting for child process #{pid} to complete."
        begin
          Process.wait( pid )
          log "Process #{pid} has terminated"
        rescue Errno::ECHILD
          log "Child process with id #{pid} does not exist"
        end

        mutex.set( nil ) if pid == mutex_pid
        delete_socket
      end

      def exit
        shutdown
        mutex.release
      end

      def restart
        log 'Restarting webpack-dev-server...'
        shutdown
        run
      end

      def check_existing_pid
        existing_pid = mutex.get
        if existing_pid
          log "Found existing PID #{existing_pid} in PID file"
          shutdown existing_pid
        end
      end

      def delete_socket
        File.delete( socket_path ) if File.exist?( socket_path )
      end

      def log( msg )
        Kernel.warn "[WebpackRunner] #{msg}"
      end
    end
  end
end
