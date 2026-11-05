# frozen_string_literal: true

require "presentation_helper"
require "cross_em/shell/settings_store"

class SettingsStoreTest < Minitest::Test
  include PresentationTest

  def stored(folder) = Settings.parse(folder.read(Settings::FILE))

  def test_a_development_theme_is_shown_but_not_saved
    folder = Archive::Memory.new
    store = CrossEm::Shell::SettingsStore.new(folder, appearance: :dark)
    settings = store.load

    assert_equal :dark, settings.appearance
    store.save(settings.with(muted: true))

    assert_equal :system, stored(folder).appearance
    assert stored(folder).muted
  end

  def test_a_theme_the_player_picks_is_saved
    folder = Archive::Memory.new
    store = CrossEm::Shell::SettingsStore.new(folder, appearance: :dark)
    store.save(store.load.with(appearance: :light))

    assert_equal :light, stored(folder).appearance
  end
end
