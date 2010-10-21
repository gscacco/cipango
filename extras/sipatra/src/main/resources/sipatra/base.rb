require 'sipatra/helpers'
require 'sipatra/extension_modules'
require 'benchmark'

module Sipatra
  VERSION = '1.0.0'
  
  class Base
    include HelperMethods
    attr_accessor :sip_factory, :context, :session, :msg, :params
    
    def initialize()
      @params = Hash.new {|hash,key| hash[key.to_s] if Symbol === key }
    end
    
    # called from Java to set SIP servlet bindings
    def set_bindings(*args)
      @context, @sip_factory, @session, @msg = args
      session.extend Sipatra::SessionExtension
      msg.extend Sipatra::MessageExtension
    end
    
    def session=(session)
      @session = session
      class << @session
         include SessionExtension
       end
    end
    
    # called to process a SIP request
    def do_request
      call! self.class.req_handlers
    end
    
    # called to process a SIP response
    def do_response
      call! self.class.resp_handlers
    end
    
    # Exit the current block, halts any further processing
    # of the message.
    # TODO: handle a response (as param)
    def halt
      throw :halt
    end
    
    # Pass control to the next matching handler.
    def pass
      throw :pass
    end
    
    def request?
      !msg.respond_to?(:getRequest)
    end
    
    def response?
      msg.respond_to?(:getRequest)
    end
    
    private
    
    def msg_type
      response? ? :response : :request
    end
    
    def eval_options(opts)
      opts.each_pair { |key, condition|
        pass unless header? key
        header_match = condition.match header[key]
        @params[key] = header_match.to_a if header_match
      }
    end
    
    def eval_condition(arg, keys, opts)
      #clear (for multi usage)
      @params.clear
      if request?
        match = arg.match msg.requestURI.to_s
        if match
          eval_options(opts)
          if keys.any?
            values = match.captures.to_a #Array of matched values
            keys.zip(values).each do |(k, v)|
              @params[k] = v
            end
          elsif(match.length > 1)
            @params[:uri] = match.to_a
          end
          return true
        end
      else
        if ((arg == 0) or (arg == msg.status))
          eval_options(opts)
          return true
        end
      end
      return false
    end
    
    def process_handler(handlers_hash, method_or_joker)
      if handlers = handlers_hash[method_or_joker]
        handlers.each do |pattern, keys, opts, block|
          catch :pass do
            throw :pass unless eval_condition(pattern, keys, opts)
            throw :halt, instance_eval(&block)          
          end
        end
      end
    end
    
    # Run all filters defined on superclasses and then those on the current class.
    def filter!(type, base = self.class)
      filter! type, base.superclass if base.superclass.respond_to?(:filters)
      base.filters[type].each { |block| instance_eval(&block) }
    end
    
    def call!(handlers)
      filter! :before
      catch(:halt) do
        process_handler(handlers, msg.method)
        process_handler(handlers, "_")
        filter! :default
      end
    ensure 
      filter! :after
    end
    
    class << self
      attr_reader :req_handlers, :resp_handlers, :filters
      
      # permits configuration of the application
      def configure(*envs, &block)
        yield self if envs.empty? || envs.include?(environment.to_sym)
      end
      
      # Methods defined in the block and/or in the module
      # arguments available to handlers.
      def helpers(*modules, &block)
        include(*modules) if modules.any?
        class_eval(&block) if block_given?
      end
      
      # Extension modules registered on this class and all superclasses.
      def extensions
        if superclass.respond_to?(:extensions)
          (@extensions + superclass.extensions).uniq
        else
          @extensions
        end
      end
      
      # Extends current class with all modules passed as arguements
      # if a block is present, creates a module with the block and
      # extends the current class with it.
      def register_extension(*extensions, &block)
        extensions << Module.new(&block) if block_given?
        @extensions += extensions
        extensions.each do |extension|
          extend extension
          extension.registered(self) if extension.respond_to?(:registered)
        end
      end      
      
      def response(*args, &block)
        method_name = args.shift if (!args.first.kind_of? Hash) and (!args.first.kind_of? Integer)
        code_int = args.shift if !args.first.kind_of? Hash
        opts = *args
        pattern = code_int || 0
        sip_method_name = method_name ? method_name.to_s.upcase : "_"
        handler("response_#{sip_method_name}  \"#{pattern}\"", sip_method_name, pattern, [], opts || {}, &block)
      end
      
      [:ack, :bye, :cancel, :info, :invite, :message, 
       :notify, :options, :prack, :publish, :refer, 
       :register, :subscribe, :update, :request].each do |name|
        define_method name do |*args, &block|
          path = args.shift if (!args.first.kind_of? Hash)
          opts = *args
          uri = path || //
          pattern, keys = compile_uri_pattern(uri)
          sip_method_name = name == :request ? "_" : name.to_s.upcase
          handler("request_#{sip_method_name}  \"#{uri.kind_of?(Regexp) ? uri.source : uri}\"", sip_method_name, pattern, keys , opts || {}, &block)
        end
      end
      
      def before(msg_type = nil, &block)
        add_filter(:before, msg_type, &block)
      end
      
      def after(msg_type = nil, &block)
        add_filter(:after, msg_type, &block)
      end
      
      def default(msg_type = nil, &block)
        add_filter(:default, msg_type, &block)
      end
            
      def reset!
        @req_handlers          = {}
        @resp_handlers         = {}
        @extensions            = []
        @filters               = {:before => [], :after => [], :default => []}
      end

      def inherited(subclass)
        subclass.reset!
        super
      end
      
      def before_filters
        filters[:before]
      end

      def after_filters
        filters[:after]
      end
      
      def default_filters
        filters[:default]
      end
      
      private
      
      def add_filter(type, message_type = nil, &block)
        if message_type
          add_filter(type) do
            next unless msg_type == message_type
            instance_eval(&block)
          end
        else
          filters[type] << block
        end
      end
            
      # compiles a URI pattern
      def compile_uri_pattern(uri)
        keys = []
        if uri.respond_to? :to_str
          pattern =
          uri.to_str.gsub(/\(:(\w+)\)/) do |match|
            keys << $1.dup
                "([^:@;=?&]+)"
          end
          [/^#{pattern}$/, keys]
        elsif uri.respond_to? :match
          [uri, keys]
        else
          raise TypeError, uri
        end
      end
      
      def handler(method_name, verb, pattern, keys, options={}, &block)
        define_method method_name, &block
        unbound_method = instance_method(method_name)
        block =
        if block.arity != 0
          proc { unbound_method.bind(self).call(*@block_params) }
        else
          proc { unbound_method.bind(self).call }
        end
        handler_table(method_name, verb).push([pattern, keys, options, block]).last # TODO: conditions  
      end         
      
      def handler_table(method_name, verb)
        if method_name.start_with? "response"
         (@resp_handlers ||= {})[verb] ||= []
        else
         (@req_handlers ||= {})[verb] ||= []
        end
      end   
    end
    
    reset!
  end
  
  class Application < Base    
    def self.register_extension(*extensions, &block) #:nodoc:
      added_methods = extensions.map {|m| m.public_instance_methods }.flatten
      Delegator.delegate(*added_methods)
      super(*extensions, &block)
    end    
  end
  
  module Delegator #:nodoc:
    def self.delegate(*methods)
      methods.each do |method_name|
        eval <<-RUBY, binding, '(__DELEGATE__)', 1
          def #{method_name}(*args, &b)
            ::Sipatra::Application.send(#{method_name.inspect}, *args, &b)
          end
          private #{method_name.inspect}
        RUBY
      end
    end
    
    delegate :ack, :bye, :cancel, :info, :invite, :message,
      :notify, :options, :prack, :publish, :refer, 
      :register, :subscribe, :update, 
      :helpers, :configure,
      :before, :after, :request, :response
  end
  
  def self.helpers(*extensions, &block)
    Application.helpers(*extensions, &block)
  end  
  
  def self.register_extension(*extensions, &block)
    Application.register_extension(*extensions, &block)
  end
end