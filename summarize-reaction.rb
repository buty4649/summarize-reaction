#!/usr/bin/env ruby

require 'thor'
require 'slack-ruby-client'

class SummarizeReaction < Thor
  default_command :exec
  INTERVAL = 0.05

  desc 'exec', 'exec'
  def exec
    client = initialize_slack
    user = get_user(client)

    current_page = 1
    paging = nil
    summary = Hash.new(0)

    while next_page?(paging, current_page)
      query = "from:#{user} has:reaction"

      result = ok? client.search_messages(query: query, count: 100, page: current_page)
      current_page += 1

      messages = result['messages']
      paging = messages['paging']
      messages['matches'].each do |match|
        channel = match.channel.id
        ts = match.ts

        reactions = ok?(
          client.reactions_get(
            channel: channel, timestamp: ts, full: true
          )
        )['message']['reactions']

        reactions.each do |r|
          count = r['count']
          name = r['name']
          summary[name] += count
        end

        sleep INTERVAL
      end
    end

    puts "message total: #{paging['total']}"
    puts "reaction total: #{summary.values.inject(&:+)}"
    puts
    puts "reactions"
    puts "---------"
    summary.each_pair{|k,v| puts "#{k}: #{v}"}
  end

  private
  def initialize_slack
    raise 'please set $SLACK_API_TOKEN' unless ENV['SLACK_API_TOKEN']

    Slack.configure do |config|
      config.token = ENV['SLACK_API_TOKEN']
    end
    
    Slack::Web::Client.new
  end

  def ok?(result)
    unless result['ok']
      raise result['error']
    end
    result
  end

  def get_user(client)
    client.auth_test['user']
  end

  def next_page?(paging, current_page)
    last_page = paging.nil? ? 100 : paging['pages']
    paging.nil? or current_page <= last_page
  end
end

SummarizeReaction.start(ARGV)
