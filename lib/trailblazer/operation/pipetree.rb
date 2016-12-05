require "pipetree"
require "pipetree/flow"
require "trailblazer/operation/result"
require "uber/option"

class Trailblazer::Operation
  New = ->(klass, options) { klass.new(options) } # returns operation instance.

  # Implements the API to populate the operation's pipetree and
  # `Operation::call` to invoke the latter.
  # http://trailblazer.to/gems/operation/2.0/pipetree.html
  module Pipetree
    def self.included(includer)
      includer.extend ClassMethods # ::call, ::inititalize_pipetree!
      includer.extend DSL          # ::|, ::> and friends.

      includer.initialize_pipetree!
      includer.>> New, name: "operation.new", wrap: false
    end

    module ClassMethods
      # Top-level, this method is called when you do Create.() and where
      # all the fun starts, ends, and hopefully starts again.
      def call(options)
        pipe = self["pipetree"] # TODO: injectable? WTF? how cool is that?

        last, operation = pipe.(self, options)

        # The reason the Result wraps the Skill object (`options`), not the operation
        # itself is because the op should be irrelevant, plus when stopping the pipe
        # before op instantiation, this would be confusing (and wrong!).
        Result.new(last == ::Pipetree::Flow::Right, options)
      end

      # This method would be redundant if Ruby had a Class::finalize! method the way
      # Dry.RB provides it. It has to be executed with every subclassing.
      def initialize_pipetree!
        heritage.record :initialize_pipetree!
        self["pipetree"] = ::Pipetree::Flow[]
      end
    end

    module DSL
      # They all inherit.
      def >>(*args); _insert(:>>, *args) end
      def >(*args); _insert(:>, *args) end
      def &(*args); _insert(:&, *args) end
      def <(*args); _insert(:<, *args) end

      # self.| ->(*) { }, before: "operation.new"
      # self.| :some_method
      def |(cfg, user_options={})
        DSL.import(self, self["pipetree"], cfg, user_options) &&
          heritage.record(:|, cfg, user_options)
      end

      alias_method :step, :|

      # :public:
      # Wrap the step into a proc that only passes `options` to the step.
      # This is pure convenience for the developer and will be the default
      # API for steps. ATM, we also automatically generate a step `:name`.
      def self.insert(pipe, operator, proc, options={}, definer_name:nil) # TODO: definer_name is a hack for debugging, only.
        # proc = Uber::Option[proc]

        _proc =
          if options[:wrap] == false
            proc
          elsif proc.is_a? Symbol
            options[:name] ||= proc
            ->(input, _options) { input.send(proc, _options) }
          elsif proc.is_a? Proc
            options[:name] ||= "#{definer_name}:#{proc.source_location.last}" if proc.is_a? Proc
            # ->(input, options) { proc.(**options) }
            ->(input, _options) { proc.(_options) }
          elsif proc.is_a? Uber::Callable
            options[:name] ||= proc.class
            ->(input, _options) { proc.(_options) }
          end

        pipe.send(operator, _proc, options) # ex: pipetree.> Validate, after: Model::Build
      end

      def self.import(operation, pipe, cfg, user_options={})
        if cfg.is_a?(Array) # e.g. from Contract::Validate
          mod, args, block = cfg

          import = Import.new(pipe, user_options) # API object.

          return mod.import!(operation, import, *args, &block)
        end

        insert(pipe, :>, cfg, user_options, {}) # DOEES NOOOT calls heritage.record
      end

      Macros = Module.new
      def self.macro!(name, constant)
        Macros.send :define_method, name do |*args, &block|
          [constant, args, block]
        end
      end


      # :private:
      # High-level user step API that allows ->(options) procs.
      def _insert(operator, proc, options={})
        heritage.record(:_insert, operator, proc, options)

        DSL.insert(self["pipetree"], operator, proc, options, definer_name: self.name)
      end

      def ~(cfg)
        heritage.record(:~, cfg)

        self.|(cfg, inheriting: true) # FIXME: not sure if this is the final API.
      end

      # Try to abstract as much as possible from the imported module. This is for
      # forward-compatibility.
      # Note that Import#call will push the step directly on the pipetree which gives it the
      # low-level (input, options) interface.
      Import = Struct.new(:pipetree, :user_options) do
        def call(operator, step, options)
          pipetree.send operator, step, options.merge(user_options)
        end

        def inheriting?
          user_options[:inheriting]
        end
      end
    end
  end

  extend Pipetree::DSL::Macros
end
