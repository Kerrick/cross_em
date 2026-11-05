# frozen_string_literal: true

module CrossEm
  module Presentation
    # Light or dark: the player's choice, which by default is to follow
    # the system. A system that cannot say (:unknown) gets the light page.
    module Appearance
      CHOICES = %i[system light dark].freeze

      module_function

      def dark?(choice, system_theme) = choice == :dark || (choice == :system && system_theme == :dark)

      # The choice after the header's button flips the page shown, light
      # to dark or dark to light. When that is what the system shows, the
      # choice is to follow the system again, so the page keeps following
      # it (at sunset, say); otherwise it is the page asked for. A system
      # that cannot say gets the page asked for.
      def flip(choice, system_theme)
        wanted = dark?(choice, system_theme) ? :light : :dark
        system_theme == wanted ? :system : wanted
      end

      def parse(text, default = :system) = CHOICES.find { it.to_s == text.to_s } || default
    end
  end
end
