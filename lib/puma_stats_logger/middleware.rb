module PumaStatsLogger
  class Middleware
    def initialize(app, options = {})
      @app = app
      @logger = options[:logger] || Logger.new($stdout)
    end

    def call(env)
      status, headers, body = @app.call(env)
      log_puma_stats if puma_options
      [status, headers, body]
    end

    private

    def puma_options
      @puma_options ||= begin
        return nil unless File.exists?(puma_state_file)
        YAML.load_file(puma_state_file) #['config'].options
      end
    end

    def puma_state_file
      'tmp/puma.state'
    end

    def log_puma_stats
      stats = Socket.unix(puma_options[:control_url].gsub('unix://', '')) do |socket|
        socket.print("GET /stats?token=#{puma_options[:control_auth_token]} HTTP/1.0\r\n\r\n")
        socket.read
      end

      stats = JSON.parse(stats.split("\r\n").last)
      line = String.new.tap do |s|
        s << "source=#{ENV['DYNO']} " if ENV['DYNO']
        s << stats.map{|k,v| "measure#puma.#{k}=#{v}"}.join(' ')
      end

      @logger.info line
    end
  end
end