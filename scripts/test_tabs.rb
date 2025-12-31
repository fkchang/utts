#!/usr/bin/env ruby
# frozen_string_literal: true

# Minimal tab test to verify StreamWeaver tabs work
# Run: ruby scripts/test_tabs.rb

require 'bundler/setup'
require 'stream_weaver'

app "Tab Test", layout: :wide do
  tabs :test_tabs, variant: :enclosed do
    tab "Tab 1" do
      text "This is tab 1"
    end
    tab "Tab 2" do
      text "This is tab 2"
    end
    tab "Tab 3" do
      text "This is tab 3"
    end
  end
end.run!
