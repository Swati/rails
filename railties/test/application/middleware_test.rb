require 'isolation/abstract_unit'
require 'stringio'

module ApplicationTests
  class MiddlewareTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
      FileUtils.rm_rf "#{app_path}/config/environments"
    end

    def app
      @app ||= Rails.application
    end

    test "default middleware stack" do
      boot!

      assert_equal [
        "ActionDispatch::Static",
        "Rack::Lock",
        "ActiveSupport::Cache::Strategy::LocalCache",
        "Rack::Runtime",
        "Rails::Rack::Logger",
        "ActionDispatch::ShowExceptions",
        "ActionDispatch::RemoteIp",
        "Rack::Sendfile",
        "ActionDispatch::Callbacks",
        "ActiveRecord::ConnectionAdapters::ConnectionManagement",
        "ActiveRecord::QueryCache",
        "ActionDispatch::Cookies",
        "ActionDispatch::Session::CookieStore",
        "ActionDispatch::Flash",
        "ActionDispatch::ParamsParser",
        "Rack::MethodOverride",
        "ActionDispatch::Head",
        "ActionDispatch::BestStandardsSupport"
      ], middleware
    end

    test "Rack::Cache is present when action_controller.perform_caching is set" do
      add_to_config "config.action_controller.perform_caching = true"

      boot!

      assert_equal [
        "Rack::Cache",
        "ActionDispatch::Static",
        "Rack::Lock",
        "ActiveSupport::Cache::Strategy::LocalCache",
        "Rack::Runtime",
        "Rails::Rack::Logger",
        "ActionDispatch::ShowExceptions",
        "ActionDispatch::RemoteIp",
        "Rack::Sendfile",
        "ActionDispatch::Callbacks",
        "ActiveRecord::ConnectionAdapters::ConnectionManagement",
        "ActiveRecord::QueryCache",
        "ActionDispatch::Cookies",
        "ActionDispatch::Session::CookieStore",
        "ActionDispatch::Flash",
        "ActionDispatch::ParamsParser",
        "Rack::MethodOverride",
        "ActionDispatch::Head",
        "ActionDispatch::BestStandardsSupport"
      ], middleware
    end

    test "removing Active Record omits its middleware" do
      use_frameworks []
      boot!
      assert !middleware.include?("ActiveRecord::ConnectionAdapters::ConnectionManagement")
      assert !middleware.include?("ActiveRecord::QueryCache")
    end

    test "removes lock if allow concurrency is set" do
      add_to_config "config.allow_concurrency = true"
      boot!
      assert !middleware.include?("Rack::Lock")
    end

    test "removes static asset server if serve_static_assets is disabled" do
      add_to_config "config.serve_static_assets = false"
      boot!
      assert !middleware.include?("ActionDispatch::Static")
    end

    test "can delete a middleware from the stack" do
      add_to_config "config.middleware.delete ActionDispatch::Static"
      boot!
      assert !middleware.include?("ActionDispatch::Static")
    end

    test "removes show exceptions if action_dispatch.show_exceptions is disabled" do
      add_to_config "config.action_dispatch.show_exceptions = false"
      boot!
      assert !middleware.include?("ActionDispatch::ShowExceptions")
    end

    test "use middleware" do
      use_frameworks []
      add_to_config "config.middleware.use Rack::Config"
      boot!
      assert_equal "Rack::Config", middleware.last
    end

    test "insert middleware after" do
      add_to_config "config.middleware.insert_after ActionDispatch::Static, Rack::Config"
      boot!
      assert_equal "Rack::Config", middleware.second
    end

    test "RAILS_CACHE does not respond to middleware" do
      add_to_config "config.cache_store = :memory_store"
      boot!
      assert_equal "Rack::Runtime", middleware.third
    end

    test "RAILS_CACHE does respond to middleware" do
      boot!
      assert_equal "Rack::Runtime", middleware.fourth
    end

    test "insert middleware before" do
      add_to_config "config.middleware.insert_before ActionDispatch::Static, Rack::Config"
      boot!
      assert_equal "Rack::Config", middleware.first
    end

    test "show exceptions middleware filter backtrace before logging" do
      my_middleware = Struct.new(:app) do
        def call(env)
          raise "Failure"
        end
      end

      make_basic_app do |app|
        app.config.middleware.use my_middleware
      end

      stringio = StringIO.new
      Rails.logger = Logger.new(stringio)

      env = Rack::MockRequest.env_for("/")
      Rails.application.call(env)
      assert_no_match(/action_dispatch/, stringio.string)
    end

    private

      def boot!
        require "#{app_path}/config/environment"
      end

      def middleware
        AppTemplate::Application.middleware.map(&:klass).map(&:name)
      end
  end
end
