require 'sinatra'
require 'dalli'
require 'haml'


require 'amnesia/host'
require 'amnesia/pie'
require 'core_ext/array'

module Amnesia
  class << self
    attr_accessor :config
  end
  
  class Application < Sinatra::Base
    set :public_folder, File.join(File.dirname(__FILE__), 'amnesia', 'public')
    set :views, File.join(File.dirname(__FILE__), 'amnesia', 'views')

    def initialize(app, configuration = {})
      Amnesia.config = configuration
      # Heroku
      Amnesia.config[:hosts] ||= [nil] if ENV['MEMCACHE_SERVERS']
      # Default if nothing set
      Amnesia.config[:hosts] ||= ['127.0.0.1:11211']
      super(app)
    end
    
    helpers do
      def graph_url(data = [], holder = {})
        js =<<CODE
        <script>
            $(function () {
                var r = new Raphael("#{holder}", 120, 120),
                    pie = r.piechart(60, 60, 50, [#{data.join(",")}], {colors:["#FF0000","#006699"]});

                pie.hover(function () {
                    this.sector.stop();
                    this.sector.scale(1.1, 1.1, this.cx, this.cy);

                }, function () {
                    this.sector.animate({ transform: 's1 1 ' + this.cx + ' ' + this.cy }, 500, "bounce");

                });
            });

        </script>
CODE
      end
      
      def number_to_human_size(size, precision=1)
        return '0' if size == 0
        units = %w{B KB MB GB TB}
        e = (Math.log(size)/Math.log(1024)).floor
        s = "%.#{precision}f" % (size.to_f / 1024**e)
        s.sub(/\.?0*$/, ' '+units[e])
      end


      def protected!
        unless authorized?
          response['WWW-Authenticate'] = %(Basic realm="Amnesia")
          throw(:halt, [401, "Not authorized\n"])
        end
      end

      def authorized?
        if ENV['AMNESIA_CREDS']
          @auth ||=  Rack::Auth::Basic::Request.new(request.env)
          @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == ENV['AMNESIA_CREDS'].split(':')
        else
          # No auth needed.
          true
        end
      end
    end
    
    get '/amnesia' do
      protected!
      @hosts = Amnesia.config[:hosts].map{|host| Amnesia::Host.new(host)}
      haml :index
    end

    get '/amnesia/:host' do
      protected!
      @host = Amnesia::Host.new(params[:host])
      haml :host
    end
  end
end
