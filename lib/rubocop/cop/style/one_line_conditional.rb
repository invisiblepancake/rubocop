# frozen_string_literal: true

module RuboCop
  module Cop
    module Style
      class OneLineConditional < Base
        include Alignment
        include ConfigurableEnforcedStyle
        include OnNormalIfUnless
        extend AutoCorrector

        OFFENSE_MESSAGE = 'Favor the ternary operator (`?:`) or multi-line constructs ' \
                          'over single-line `%<keyword>s/then/else/end` constructs.'

        def on_normal_if_unless(node)
          return if invalid_node?(node)

          message = format_message(node)
          add_offense(node, message: message) do |corrector|
            autocorrect_node(corrector, node)
          end
        end

        private

        def invalid_node?(node)
          !node.single_line? || node.else_branch.nil? || node.elsif? || node.if_branch&.begin_type?
        end

        def format_message(node)
          format(OFFENSE_MESSAGE, keyword: node.keyword)
        end

        def autocorrect_node(corrector, node)
          return if part_of_ignored_node?(node)

          if always_multiline? || cannot_replace_to_ternary?(node)
            IfThenCorrector.new(node, indentation: configured_indentation_width).call(corrector)
          else
            corrector.replace(node, ternary_correction(node))
          end

          ignore_node(node)
        end

        def ternary_correction(node)
          replaced_node = ternary_replacement(node)

          return replaced_node unless node.parent
          return "(#{replaced_node})" if node.parent.operator_keyword?
          return "(#{replaced_node})" if node.parent.send_type? && node.parent.operator_method?

          replaced_node
        end

        def always_multiline?
          cop_config['AlwaysCorrectToMultiline']
        end

        def cannot_replace_to_ternary?(node)
          return true if node.elsif_conditional?

          node.else_branch.begin_type? && node.else_branch.children.compact.count >= 2
        end

        def ternary_replacement(node)
          condition, if_branch, else_branch = *node

          "#{expr_replacement(condition)} ? " \
            "#{expr_replacement(if_branch)} : " \
            "#{expr_replacement(else_branch)}"
        end

        def expr_replacement(node)
          return 'nil' if node.nil?

          requires_parentheses?(node) ? "(#{node.source})" : node.source
        end

        def requires_parentheses?(node)
          return true if %i[and or if].include?(node.type)
          return true if node.assignment?
          return true if method_call_with_changed_precedence?(node)

          keyword_with_changed_precedence?(node)
        end

        def method_call_with_changed_precedence?(node)
          return false unless node.send_type? && node.arguments?
          return false if node.parenthesized_call?

          !node.operator_method?
        end

        def keyword_with_changed_precedence?(node)
          return false unless node.keyword?
          return true if node.respond_to?(:prefix_not?) && node.prefix_not?

          node.respond_to?(:arguments?) && node.arguments? && !node.parenthesized_call?
        end
      end
    end
  end
end
