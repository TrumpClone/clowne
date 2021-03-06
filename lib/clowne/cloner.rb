# frozen_string_literal: true

require 'clowne/planner'
require 'clowne/dsl'

module Clowne # :nodoc: all
  class UnprocessableSourceError < StandardError; end
  class ConfigurationError < StandardError; end

  class Cloner
    extend Clowne::DSL

    class << self
      def inherited(subclass)
        subclass.adapter(adapter) unless self == Clowne::Cloner
        subclass.declarations = declarations.dup

        return if traits.nil?

        traits.each do |name, trait|
          subclass.traits[name] = trait.dup
        end
      end

      def declarations
        return @declarations if instance_variable_defined?(:@declarations)
        @declarations = []
      end

      def traits
        return @traits if instance_variable_defined?(:@traits)
        @traits = {}
      end

      def register_trait(name, block)
        @traits ||= {}
        @traits[name] ||= Declarations::Trait.new
        @traits[name].extend_with(block)
      end

      # rubocop: disable Metrics/AbcSize
      # rubocop: disable Metrics/MethodLength
      def call(object, **options)
        raise(UnprocessableSourceError, 'Nil is not cloneable object') if object.nil?

        raise(ConfigurationError, 'Adapter is not defined') if adapter.nil?

        traits = options.delete(:traits)

        traits = Array(traits) unless traits.nil?

        plan =
          if traits.nil? || traits.empty?
            default_plan
          else
            plan_with_traits(traits)
          end

        adapter.clone(object, plan, params: options)
      end

      # rubocop: enable Metrics/AbcSize
      # rubocop: enable Metrics/MethodLength

      def default_plan
        return @default_plan if instance_variable_defined?(:@default_plan)
        @default_plan = Clowne::Planner.compile(self)
      end

      def plan_with_traits(ids)
        # Cache plans for combinations of traits
        traits_id = ids.map(&:to_s).join(':')
        return traits_plans[traits_id] if traits_plans.key?(traits_id)
        traits_plans[traits_id] = Clowne::Planner.compile(
          self, traits: ids
        )
      end

      protected

      attr_writer :declarations

      private

      def traits_plans
        return @traits_plans if instance_variable_defined?(:@traits_plans)
        @traits_plans = {}
      end
    end
  end
end
