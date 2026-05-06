module Assistants
  module Tools
    class Base
      attr_reader :user

      def initialize(user)
        @user = user
      end

      def name
        raise NotImplementedError
      end

      def description
        raise NotImplementedError
      end

      def input_schema
        raise NotImplementedError
      end

      def definition
        { name: name, description: description, input_schema: input_schema }
      end

      def call(args)
        raise NotImplementedError
      end

      private

      def stringify_keys(h)
        h.transform_keys(&:to_s)
      end

      def fmt_amount(v)
        return nil if v.nil?
        format("%.2f", v.to_f)
      end
    end
  end
end
