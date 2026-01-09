# frozen_string_literal: true

require 'json'
require 'securerandom'
require 'time'

module Utts
  class Notification
    attr_reader :id, :text, :caller, :agent, :voice, :timestamp, :metadata, :dismissed_at

    def initialize(
      text:,
      caller: nil,
      agent: nil,
      voice: nil,
      metadata: {},
      id: nil,
      timestamp: nil,
      dismissed_at: nil
    )
      @id = id || SecureRandom.hex(4)
      @text = text
      @caller = caller
      @agent = agent
      @voice = voice
      @timestamp = timestamp || Time.now.utc.iso8601
      @metadata = metadata || {}
      @dismissed_at = dismissed_at
    end

    def dismissed?
      !@dismissed_at.nil?
    end

    def dismiss!
      @dismissed_at = Time.now.utc.iso8601
    end

    def to_h
      {
        id: @id,
        text: @text,
        caller: @caller,
        agent: @agent,
        voice: @voice,
        timestamp: @timestamp,
        metadata: @metadata,
        dismissed_at: @dismissed_at
      }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end

    def self.from_hash(hash)
      new(
        id: hash['id'] || hash[:id],
        text: hash['text'] || hash[:text],
        caller: hash['caller'] || hash[:caller],
        agent: hash['agent'] || hash[:agent],
        voice: hash['voice'] || hash[:voice],
        timestamp: hash['timestamp'] || hash[:timestamp],
        metadata: hash['metadata'] || hash[:metadata] || {},
        dismissed_at: hash['dismissed_at'] || hash[:dismissed_at]
      )
    end

    def self.from_json(json_string)
      from_hash(JSON.parse(json_string))
    end
  end
end
