# frozen_string_literal: true

module CrossEm
  module Presentation
    # Light or dark: the player's choice, which by default is to follow
    # the system. A system that cannot say (:unknown) gets the light page.
    module Appearance
      CHOICES = %i[system light dark].freeze

      module_function

      def dark?(choice, system_theme) = choice == :dark || (choice == :system && system_theme == :dark)

      # The choice after +choice+, as the header's button cycles them.
      def next(choice) = CHOICES[(CHOICES.index(choice).to_i + 1) % CHOICES.size]

      def parse(text, default = :system) = CHOICES.find { it.to_s == text.to_s } || default
    end
  end
end
